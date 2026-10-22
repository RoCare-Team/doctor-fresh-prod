import 'package:flutter/material.dart';

import '../app_tabs.dart';
import '../core/theme.dart';
import '../router.dart';
import '../screens/cart_screens.dart';
import '../screens/catalog_screens.dart';
import '../state/app_state.dart';

/// The page frame every screen uses: a compact native app bar (back, title,
/// search and cart) over a light grey canvas, so white cards stand out the
/// way they do in a shopping app. The bottom tab bar lives in [MainShell];
/// pages pushed on top of it cover it, as in any native app.
class DFScaffold extends StatelessWidget {
  const DFScaffold({
    super.key,
    required this.body,
    this.title,
    this.showSearch = false,
    this.showCart = true,
    this.showDock = false,
    this.bottomBar,
    this.checkoutMode = false,
    this.backgroundColor = DF.canvas,
    this.actions = const [],
  });

  final Widget body;

  /// Shown in the app bar; the logo stands in when there is none.
  final String? title;
  final bool showSearch;
  final bool showCart;

  /// Kept for the screens that still pass it; the floating WhatsApp / call
  /// buttons were a website element and the app shows help in Account.
  final bool showDock;
  final Widget? bottomBar;
  final bool checkoutMode;
  final Color backgroundColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: DFAppBar(
        title: title,
        showSearch: showSearch,
        showCart: showCart && !checkoutMode,
        secure: checkoutMode,
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottomBar == null
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x1A0F172A), blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: SafeArea(top: false, child: bottomBar!),
            ),
    );
  }
}

class DFAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DFAppBar({
    super.key,
    this.title,
    this.showSearch = false,
    this.showCart = true,
    this.secure = false,
    this.actions = const [],
  });

  final String? title;
  final bool showSearch;
  final bool showCart;
  final bool secure;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    // This page's own route, so an open sheet above it does not add a back arrow.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final state = AppScope.of(context);

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: canPop ? 0 : 16,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: DF.ink900),
            )
          : null,
      title: title == null || title!.isEmpty
          ? Image.asset('assets/images/logo2-trimmed.png', height: 28, fit: BoxFit.contain)
          : Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, color: DF.ink900, letterSpacing: -0.2),
            ),
      actions: [
        ...actions,
        if (secure)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: DF.success, size: 16),
                SizedBox(width: 4),
                Text('Secure', style: TextStyle(color: DF.success, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ],
            ),
          ),
        if (showSearch && !secure)
          IconButton(
            tooltip: 'Search',
            onPressed: () => AppRouter.push(context, const SearchScreen()),
            icon: const Icon(Icons.search_rounded, color: DF.ink900),
          ),
        if (showCart && !secure) ...[
          CartIconButton(count: state.cartCount),
          const SizedBox(width: 6),
        ],
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: DF.line),
      ),
    );
  }
}

/// The cart with its count; opens the cart page.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key, required this.count, this.color = DF.ink900});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => AppRouter.push(context, const CartScreen()),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: DF.primary600,
        label: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        child: Icon(Icons.shopping_bag_outlined, color: color),
      ),
    );
  }
}

/// A tappable search pill (home and categories).
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, this.hint = 'Search purifiers, RO plants, spares…', this.onCanvas = false});
  final String hint;

  /// Grey fill when it sits on white; white when it sits on colour.
  final bool onCanvas;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onCanvas ? DF.canvas : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => AppRouter.push(context, const SearchScreen()),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, size: 21, color: DF.ink400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DF.ink300, fontSize: 14.5)),
              ),
              Container(width: 1, height: 22, color: DF.line),
              IconButton(
                tooltip: 'Categories',
                onPressed: () => AppTabs.go(context, AppTabs.categories),
                icon: const Icon(Icons.tune_rounded, size: 20, color: DF.primary600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
