import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/widgets/nav_bar/animated_bottom_nav_bar.dart';
import 'package:inventory_1/core/widgets/nav_bar/nav_destination.dart';

void main() {
  const destinations = [
    NavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavDestination(icon: Icons.shopping_cart_outlined, label: 'Sales'),
    NavDestination(icon: Icons.inventory_2_outlined, label: 'Stock'),
    NavDestination(icon: Icons.group_outlined, label: 'Clients'),
    NavDestination(icon: Icons.more_horiz_rounded, label: 'Menu'),
  ];

  testWidgets('expands the selected destination and changes selection', (
    tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AnimatedBottomNavBar(
                selectedIndex: selectedIndex,
                destinations: destinations,
                onSelected: (index) => setState(() => selectedIndex = index),
              ),
            );
          },
        ),
      ),
    );

    final homeWidth = tester
        .getSize(find.byKey(const ValueKey('nav-item-0')))
        .width;
    final salesWidth = tester
        .getSize(find.byKey(const ValueKey('nav-item-1')))
        .width;
    expect(homeWidth, greaterThan(salesWidth));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sales'), findsNothing);
    expect(
      tester.getSize(find.byType(AnimatedBottomNavBar)).height,
      lessThan(100),
    );

    await tester.tap(find.bySemanticsLabel('Sales'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('nav-item-1'))).width,
      greaterThan(
        tester.getSize(find.byKey(const ValueKey('nav-item-0'))).width,
      ),
    );
  });

  testWidgets('uses the separate menu action when provided', (tester) async {
    var selectedIndex = 0;
    var menuTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AnimatedBottomNavBar(
            selectedIndex: selectedIndex,
            destinations: destinations,
            onSelected: (index) => selectedIndex = index,
            onMoreTap: () => menuTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();

    expect(menuTapped, isTrue);
    expect(selectedIndex, 0);
  });
}
