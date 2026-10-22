import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/storage.dart';

/// Everything the screens share: the signed-in customer, the cart, the
/// wishlist, the service basket and the navigation data. One ChangeNotifier,
/// reached through [AppScope.of].
///
/// The cart follows the website (components/cart/CartProvider.jsx): kept on
/// the device under `df_cart_guest` while signed out and `df_cart_user_<id>`
/// once signed in, the guest cart merged in at sign-in.
class AppState extends ChangeNotifier {
  User? user;
  bool sessionChecked = false;

  final List<CartLine> cart = [];
  Set<int> wishlist = {};
  final List<ServiceLine> serviceCart = [];

  /// /api/mobile/menu — categories, blog categories, legal pages, brand.
  Map<String, dynamic>? menu;

  /// Where the customer is: `{pincode, area, city, state}` from
  /// /api/geo/reverse, kept on the phone so the header shows it at once.
  Map<String, dynamic>? place;

  /// idle · locating · ok · denied · off · unavailable
  String locationStatus = 'idle';

  bool get signedIn => user != null;

  String get _cartKey => user == null ? 'df_cart_guest' : 'df_cart_user_${user!.id}';

  Future<void> init() async {
    _loadCart();
    _loadServiceCart();
    place = Store.instance.get<Map>('df_location')?.cast<String, dynamic>();
    notifyListeners();
    // Asked as the app opens, as shopping apps do.
    locate();
    await refreshSession();
    loadMenu();
  }

  /* ------------------------------------------------------------ location */

  /// Asks the phone where it is (permission the first time), then turns the
  /// position into an area and pin code with the site's /api/geo/reverse.
  Future<void> locate() async {
    if (locationStatus == 'locating') return;
    locationStatus = 'locating';
    notifyListeners();

    final spot = await Native.location();
    if (spot['lat'] == null || spot['lon'] == null) {
      locationStatus = '${spot['error'] ?? 'unavailable'}';
      notifyListeners();
      return;
    }

    final res = await Api.instance.get('/api/geo/reverse', query: {'lat': spot['lat'], 'lon': spot['lon']});
    if (res.ok) {
      place = {
        'pincode': str(res.map['pincode']),
        'area': str(res.map['area']),
        'city': str(res.map['city']),
        'state': str(res.map['state']),
      };
      locationStatus = 'ok';
      await Store.instance.set('df_location', place);
      // The delivery check on product pages starts from this pin code.
      await Store.instance.set('df_pincode', place!['pincode']);
    } else {
      locationStatus = 'unavailable';
    }
    notifyListeners();
  }

  /// "Sector 47, Gurgaon 122018"
  String get placeLabel {
    final p = place;
    if (p == null) return '';
    final area = str(p['area']).split(',').last.trim();
    final city = str(p['city']);
    final head = [area, city].where((s) => s.isNotEmpty).toSet().join(', ');
    return '$head ${str(p['pincode'])}'.trim();
  }

  /* ------------------------------------------------------------- session */

  Future<void> refreshSession() async {
    final res = await Api.instance.get('/api/auth/me');
    final u = res.map['user'];
    final before = user?.id;
    if (res.status == 200) {
      user = u is Map ? User.fromJson(u) : null;
    }
    sessionChecked = true;
    if (user?.id != before) {
      _switchCart();
    }
    await loadWishlist();
    notifyListeners();
  }

  /// Called after /api/auth/verify-otp succeeded (the cookie is already kept).
  Future<void> signedInAs(Map userJson) async {
    user = User.fromJson(userJson);
    _switchCart(mergeGuest: true);
    await loadWishlist();
    notifyListeners();
  }

  Future<void> signOut() async {
    await Api.instance.post('/api/auth/logout');
    await Api.instance.clearCookies();
    user = null;
    wishlist = {};
    _switchCart();
    notifyListeners();
  }

  /* ---------------------------------------------------------------- cart */

  void _loadCart() {
    cart
      ..clear()
      ..addAll((Store.instance.get<List>(_cartKey) ?? const []).whereType<Map>().map(CartLine.fromJson));
  }

  void _switchCart({bool mergeGuest = false}) {
    final guest = (Store.instance.get<List>('df_cart_guest') ?? const []).whereType<Map>().map(CartLine.fromJson).toList();
    _loadCart();
    if (mergeGuest && user != null && guest.isNotEmpty) {
      for (final g in guest) {
        if (!cart.any((c) => c.id == g.id)) cart.add(g);
      }
      Store.instance.remove('df_cart_guest');
      _saveCart();
    }
  }

  void _saveCart() {
    if (cart.isEmpty) {
      Store.instance.remove(_cartKey);
    } else {
      Store.instance.set(_cartKey, cart.map((c) => c.toJson()).toList());
    }
  }

  bool inCart(int id) => cart.any((c) => c.id == id);

  int get cartCount => cart.fold(0, (n, c) => n + c.qty);
  num get subtotal => cart.fold<num>(0, (n, c) => n + c.price * c.qty);
  num get mrpTotal => cart.fold<num>(0, (n, c) => n + (c.mrp > 0 ? c.mrp : c.price) * c.qty);
  num get savings => mrpTotal - subtotal;

  /// Adding something already in the cart does nothing, as on the site.
  void addToCart(CartLine line) {
    if (inCart(line.id)) return;
    line.qty = line.qty.clamp(1, line.maxQty);
    cart.add(line);
    _saveCart();
    notifyListeners();
  }

  void setQty(int id, int qty) {
    final line = cart.where((c) => c.id == id).firstOrNull;
    if (line == null) return;
    line.qty = qty.clamp(1, line.maxQty);
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(int id) {
    cart.removeWhere((c) => c.id == id);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    _saveCart();
    notifyListeners();
  }

  /* ------------------------------------------------------------ wishlist */

  Future<void> loadWishlist() async {
    final res = await Api.instance.get('/api/wishlist');
    wishlist = ((res.map['ids'] as List?) ?? const []).map((e) => toInt(e)).toSet();
    notifyListeners();
  }

  bool saved(int id) => wishlist.contains(id);

  /// Returns false when the customer has to sign in first.
  Future<bool> toggleWishlist(int id) async {
    if (!signedIn) return false;
    final was = saved(id);
    if (was) {
      wishlist.remove(id);
    } else {
      wishlist.add(id);
    }
    notifyListeners();
    final res = await Api.instance.post('/api/wishlist', {'productId': id});
    if (res.needsSignIn) {
      user = null;
      notifyListeners();
      return false;
    }
    if (res.ok && res.map['ids'] is List) {
      wishlist = (res.map['ids'] as List).map((e) => toInt(e)).toSet();
    } else if (!res.ok) {
      was ? wishlist.add(id) : wishlist.remove(id);
    }
    notifyListeners();
    return true;
  }

  /* -------------------------------------------------------- service cart */

  void _loadServiceCart() {
    serviceCart
      ..clear()
      ..addAll((Store.instance.get<List>('df-service-cart') ?? const []).whereType<Map>().map(ServiceLine.fromJson));
  }

  void _saveServiceCart() {
    Store.instance.set('df-service-cart', serviceCart.map((s) => s.toJson()).toList());
  }

  int serviceQty(String id) => serviceCart.where((s) => s.id == id).firstOrNull?.qty ?? 0;

  int get serviceCount => serviceCart.fold(0, (n, s) => n + s.qty);
  num get serviceTotal => serviceCart.fold<num>(0, (n, s) => n + s.price * s.qty);
  num get serviceSaving => serviceCart.fold<num>(0, (n, s) => n + (s.mrp > s.price ? (s.mrp - s.price) * s.qty : 0));

  void setServiceQty(Map<String, dynamic> service, int qty) {
    final id = str(service['id']);
    final line = serviceCart.where((s) => s.id == id).firstOrNull;
    if (qty <= 0) {
      serviceCart.removeWhere((s) => s.id == id);
    } else if (line == null) {
      serviceCart.add(ServiceLine(
        id: id,
        name: str(service['name']),
        price: toNum(service['price']),
        mrp: toNum(service['mrp']),
        image: str(service['image']),
        group: str(service['group']),
        qty: qty.clamp(1, 5),
      ));
    } else {
      line.qty = qty.clamp(1, 5);
    }
    _saveServiceCart();
    notifyListeners();
  }

  void clearServiceCart() {
    serviceCart.clear();
    _saveServiceCart();
    notifyListeners();
  }

  /* ---------------------------------------------------------------- menu */

  Future<void> loadMenu() async {
    final res = await Api.instance.get('/api/mobile/menu');
    if (res.ok) {
      menu = res.map;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> get categories => mapsOf(menu?['categories']);
  List<Map<String, dynamic>> get blogCategories => mapsOf(menu?['blogCategories']);
  List<Map<String, dynamic>> get legalPages => mapsOf(menu?['legal']);
  Map<String, dynamic> get brand => (menu?['brand'] as Map?)?.cast<String, dynamic>() ?? const {};
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Without listening, for callbacks.
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
