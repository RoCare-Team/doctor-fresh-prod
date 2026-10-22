import 'package:flutter/material.dart';

import 'app_tabs.dart';
import 'core/config.dart';
import 'core/native.dart';
import 'screens/account_screens.dart';
import 'screens/blog_screens.dart';
import 'screens/cart_screens.dart';
import 'screens/catalog_screens.dart';
import 'screens/info_screens.dart';
import 'screens/product_screen.dart';
import 'screens/service_screens.dart';

/// Turns a website link into the app screen that shows the same page, so
/// every link the site's data carries ("/category/water-purifier",
/// "/product/slug/464", "/water-purifier-service") opens natively.
/// Anything the app has no screen for opens in the browser.
class AppRouter {
  static Future<T?> push<T>(BuildContext context, Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  static Widget? screenFor(String href) {
    final uri = Uri.tryParse(href.trim());
    if (uri == null) return null;
    final host = uri.host.replaceFirst('www.', '');
    if (uri.hasScheme &&
        !(uri.scheme.startsWith('http') && (host == 'doctorfresh.in' || host == Uri.parse(Config.baseUrl).host.replaceFirst('www.', '')))) {
      return null;
    }

    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final q = uri.queryParameters;
    if (seg.isEmpty) return null; // home: handled by the caller

    switch (seg.first) {
      case 'category':
        return CategoryScreen(path: seg.skip(1).join('/'));
      case 'spare-parts':
        return const CategoryScreen(path: 'spare-parts', title: 'Water purifier spare parts');
      case 'all-category':
        return const AllCategoriesScreen();
      case 'product':
        final id = int.tryParse(seg.last);
        return id == null ? null : ProductScreen(id: id);
      case 'search':
        return SearchScreen(query: q['q'] ?? '');
      case 'cart':
        return const CartScreen();
      case 'cart-checkout':
        return const CheckoutScreen();
      case 'login':
        return const AuthScreen();
      case 'registration':
        return const AuthScreen(register: true);
      case 'profile':
        return const ProfileScreen();
      case 'order':
        return seg.length > 1 ? OrderScreen(ref: seg[1]) : null;
      case 'blogs':
        return BlogsScreen(category: seg.length > 1 ? seg[1] : null);
      case 'blog':
        final id = seg.length > 1 ? int.tryParse(seg[1]) : null;
        return id == null ? null : BlogPostScreen(id: id);
      case 'contact':
        return const ContactScreen();
      case 'partner':
        return const PartnerScreen();
      case 'store-locator':
        return const StoresScreen();
      case 'careers':
        return const CareersScreen();
      case 'legal':
        return seg.length > 1 ? LegalScreen(slug: seg[1]) : null;
      case 'book':
        if (seg.length > 1 && seg[1] == 'checkout') return const ServiceCheckoutScreen();
        if (seg.length > 1 && seg[1] == 'done') return BookingDoneScreen(ref: q['ref'] ?? '');
        return const ServiceCartScreen();
    }

    // The service landing pages (/water-purifier-service, /ro-service-delhi,
    // /water-purifier-amc, /water-purifier-installation, …) all book through
    // the same service list.
    final slug = seg.first;
    if (seg.length == 1 && RegExp(r'service|repair|amc|install', caseSensitive: false).hasMatch(slug)) {
      final group = slug.contains('amc')
          ? '3'
          : slug.contains('install')
              ? '1'
              : '2';
      return ServicesScreen(group: group);
    }
    return null;
  }

  /// Opens [href] in the app when there is a screen for it, otherwise
  /// outside the app (browser, dialer, WhatsApp, mail).
  static Future<void> open(BuildContext context, String href) async {
    if (href.isEmpty) return;
    final uri = Uri.tryParse(href);
    final isHome =
        uri != null && uri.pathSegments.where((s) => s.isNotEmpty).isEmpty && (!uri.hasScheme || uri.host.contains('doctorfresh.in'));
    if (isHome && !href.startsWith('tel:') && !href.startsWith('mailto:')) {
      AppTabs.goHome(context);
      return;
    }
    // Pages that are tabs in the app open as that tab.
    final tab = switch (uri?.path) {
      '/all-category' => AppTabs.categories,
      '/cart' => AppTabs.cart,
      _ => null,
    };
    if (tab != null) {
      AppTabs.go(context, tab);
      return;
    }
    final screen = screenFor(href);
    if (screen != null) {
      await push(context, screen);
      return;
    }
    final external = href.startsWith('/') ? Config.url(href) : href;
    await Native.open(external, context: context);
  }
}
