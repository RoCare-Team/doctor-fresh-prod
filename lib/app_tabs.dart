import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/account_tab.dart';
import 'screens/cart_screens.dart';
import 'screens/categories_tab.dart';
import 'screens/home_screen.dart';
import 'screens/service_screens.dart';
import 'state/app_state.dart';

/// The app's home: five tabs along the bottom — Home, Cart, Shop (the
/// categories, raised in the middle as the main action), Services and
/// Account. Each keeps its own scroll position while another is
/// open; product, checkout and the other pages open on top of the tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class AppTabs {
  static const home = 0;
  static const cart = 1;
  static const categories = 2;
  static const services = 3;
  static const account = 4;

  static final ValueNotifier<int> current = ValueNotifier(home);

  /// Closes whatever is open on top and shows [tab].
  static void go(BuildContext context, int tab) {
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    current.value = tab;
  }

  static void goHome(BuildContext context) => go(context, home);
}

class _MainShellState extends State<MainShell> {
  final Set<int> _built = {AppTabs.home};

  @override
  void initState() {
    super.initState();
    AppTabs.current.addListener(_changed);
  }

  @override
  void dispose() {
    AppTabs.current.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() => _built.add(AppTabs.current.value));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final index = AppTabs.current.value;

    // A tab is built the first time it is opened, then kept.
    Widget tab(int i, Widget Function() build) => _built.contains(i) ? build() : const SizedBox.shrink();

    return PopScope(
      // Back on another tab returns to Home before leaving the app.
      canPop: index == AppTabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppTabs.current.value = AppTabs.home;
      },
      child: Scaffold(
        backgroundColor: DF.canvas,
        body: IndexedStack(
          index: index,
          children: [
            tab(AppTabs.home, () => const HomeScreen()),
            tab(AppTabs.cart, () => const CartScreen()),
            tab(AppTabs.categories, () => const CategoriesTab()),
            tab(AppTabs.services, () => const ServicesScreen()),
            tab(AppTabs.account, () => const AccountTab()),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: DF.primary100,
            height: 64,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => TextStyle(
                fontSize: 11.5,
                fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
                color: s.contains(WidgetState.selected) ? DF.primary700 : DF.ink400,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? DF.primary700 : DF.ink400),
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: DF.line))),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => AppTabs.current.value = i,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                NavigationDestination(
                  icon: _cartIcon(state.cartCount, Icons.shopping_bag_outlined),
                  selectedIcon: _cartIcon(state.cartCount, Icons.shopping_bag_rounded),
                  label: 'Cart',
                ),
                // Shop is the main action, so it stands out in the middle.
                NavigationDestination(icon: _shopIcon(false), selectedIcon: _shopIcon(true), label: 'Shop'),
                const NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build_rounded), label: 'Services'),
                const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The bag with its count, the badge kept inside the icon's box so every
  /// tab's icon and label line up.
  Widget _cartIcon(int count, IconData icon) => Badge(
        isLabelVisible: count > 0,
        backgroundColor: DF.primary600,
        offset: const Offset(8, -6),
        label: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        child: Icon(icon),
      );

  /// A filled blue circle for Shop, darker while it is the open tab. It
  /// takes the same 24px slot as the other icons and overflows it upwards,
  /// so every label stays on one line.
  Widget _shopIcon(bool selected) => SizedBox(
        width: 24,
        height: 24,
        child: OverflowBox(
          maxWidth: 46,
          maxHeight: 46,
          child: Transform.translate(
            offset: const Offset(0, -6),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? DF.primary700 : DF.primary600,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x400095DC), offset: Offset(0, 4), blurRadius: 10)],
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      );
}
