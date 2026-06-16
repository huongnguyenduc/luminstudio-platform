import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_studio_mobile/app/app.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';

void main() {
  test('ShellCubit changes selected tab', () {
    final cubit = ShellCubit();
    addTearDown(cubit.close);

    expect(cubit.state.selectedTab, CustomerTab.home);

    cubit.selectTab(CustomerTab.category);

    expect(cubit.state.selectedTab, CustomerTab.category);
  });

  testWidgets('customer shell exposes the three bottom navigation tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LuminStudioApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('No featured products yet'), findsOneWidget);
  });

  testWidgets('customer shell switches tabs without losing scroll state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LuminStudioApp());

    await tester.drag(
      find.byKey(const PageStorageKey<String>('home-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home slot 8'), findsOneWidget);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home slot 8'), findsOneWidget);
  });

  testWidgets('each tab keeps its nested navigation state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LuminStudioApp());

    await tester.tap(find.byTooltip('Home detail'));
    await tester.pumpAndSettle();
    expect(find.text('Home state retained'), findsOneWidget);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home state retained'), findsOneWidget);
  });
}
