import 'config.dart';
import 'format.dart';

/// A product as the cards show it (`mobileCard` in lib/mobile.js), and the
/// fuller product the detail page reads (/api/mobile/product/<id>).
class Product {
  Product(this.raw);
  final Map<String, dynamic> raw;

  factory Product.fromJson(dynamic json) => Product(json is Map<String, dynamic> ? json : <String, dynamic>{});

  int get id => toInt(raw['id']);
  String get slug => str(raw['slug']);
  String get name => str(raw['name']);
  String get url => str(raw['url']);
  List<String> get images => (raw['images'] as List? ?? const []).map((e) => Config.url('$e')).where((e) => e.isNotEmpty).toList();
  String get image => images.isNotEmpty ? images.first : Config.url(str(raw['image']));
  num get price => toNum(raw['price']);
  num get mrp => toNum(raw['mrp']);
  String get unit => str(raw['unit']);
  int get discountPercent => toInt(raw['discountPercent']);
  bool get inStock => raw['inStock'] != false;
  int get maxQty => toInt(raw['maxQty'], 99) > 0 ? toInt(raw['maxQty'], 99) : 99;
  num get rating => toNum(raw['rating']);
  int get reviewCount => toInt(raw['reviewCount']);
  String get metaDescription => str(raw['metaDescription']);
  List<String> get badges => (raw['badges'] as List? ?? const []).map((e) => '$e').toList();

  /// The category name on cards; `{name, href}` on the detail page.
  String get categoryName {
    final c = raw['category'];
    if (c is Map) return str(c['name']);
    return str(c);
  }

  String get categoryHref => raw['category'] is Map ? str(raw['category']['href']) : '';
  Map<String, dynamic>? get subcategory => raw['subcategory'] is Map ? Map<String, dynamic>.from(raw['subcategory']) : null;

  /// Something can be bought only with a price and stock, as the site's buttons decide.
  bool get purchasable => price > 0 && inStock;

  // detail fields
  String get descriptionHtml => str(raw['descriptionHtml']);
  String get installationHtml => str(raw['installationHtml']);
  String get shippingHtml => str(raw['shippingHtml']);
  String get videoUrl => str(raw['videoUrl']);
  String get webUrl => str(raw['webUrl']).isNotEmpty ? str(raw['webUrl']) : Config.url(url);
  List<Map<String, dynamic>> get specifications => _maps(raw['specifications']);
  List<Map<String, dynamic>> get attributes => _maps(raw['attributes']);
  List<Map<String, dynamic>> get reviews => _maps(raw['reviews']);
  List<Map<String, dynamic>> get faqs => _maps(raw['faqs']);

  /// The cart line the website stores in localStorage (CartProvider.jsx).
  CartLine toCartLine([int qty = 1]) => CartLine(
        id: id,
        name: name,
        slug: slug,
        url: url,
        image: image,
        price: price,
        mrp: mrp,
        unit: unit,
        maxQty: maxQty,
        qty: qty,
      );
}

List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

List<Map<String, dynamic>> mapsOf(dynamic v) => _maps(v);

class CartLine {
  CartLine({
    required this.id,
    required this.name,
    required this.slug,
    required this.url,
    required this.image,
    required this.price,
    required this.mrp,
    required this.unit,
    required this.maxQty,
    required this.qty,
  });

  final int id;
  final String name;
  final String slug;
  final String url;
  final String image;
  final num price;
  final num mrp;
  final String unit;
  final int maxQty;
  int qty;

  factory CartLine.fromJson(Map json) => CartLine(
        id: toInt(json['id']),
        name: str(json['name']),
        slug: str(json['slug']),
        url: str(json['url']),
        image: str(json['image']),
        price: toNum(json['price']),
        mrp: toNum(json['mrp']),
        unit: str(json['unit']),
        maxQty: toInt(json['maxQty'], 99),
        qty: toInt(json['qty'], 1),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'url': url,
        'image': image,
        'price': price,
        'mrp': mrp,
        'unit': unit,
        'maxQty': maxQty,
        'qty': qty,
      };
}

/// A service in the booking basket (lib/service-cart.js).
class ServiceLine {
  ServiceLine({
    required this.id,
    required this.name,
    required this.price,
    required this.mrp,
    required this.image,
    required this.group,
    required this.qty,
  });

  final String id;
  final String name;
  final num price;
  final num mrp;
  final String image;
  final String group;
  int qty;

  factory ServiceLine.fromJson(Map json) => ServiceLine(
        id: str(json['id']),
        name: str(json['name']),
        price: toNum(json['price']),
        mrp: toNum(json['mrp']),
        image: str(json['image']),
        group: str(json['group']),
        qty: toInt(json['qty'], 1),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'mrp': mrp,
        'image': image,
        'group': group,
        'qty': qty,
      };
}

class User {
  User({required this.id, required this.name, required this.mobile, this.email = ''});
  final int id;
  final String name;
  final String mobile;
  final String email;

  factory User.fromJson(Map json) => User(
        id: toInt(json['id']),
        name: str(json['name']),
        mobile: str(json['mobile']),
        email: str(json['email']),
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'DF';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
