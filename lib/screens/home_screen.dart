import 'dart:async';

import 'package:flutter/material.dart';

import '../app_tabs.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/purifier.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/net_image.dart';
import '../widgets/product_card.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';
import '../widgets/skeleton.dart';
import 'purifier_screen.dart';
import 'product_screen.dart';
import 'offers_tab.dart';

/// The Home tab, from GET /api/mobile/home — the website's home page content
/// laid out as a shopping app: greeting and search, promo banners, round
/// category shortcuts, quick service actions, then the deal and product rows.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? data;
  String? error;
  List<Product> recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    final res = await Api.instance.get('/api/mobile/home');
    final rv = await Api.instance.get('/api/recently-viewed');
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        data = res.map;
      } else {
        error = res.error;
      }
      recent = mapsOf(rv.map['products']).map(Product.fromJson).toList();
    });
  }

  List<Product> _products(String key) => mapsOf(data?[key]).map(Product.fromJson).toList();

  /// The offers shown further down the page, as banners: popular products
  /// first, then the rails and the deals; only real discounts on things in
  /// stock; the best one of each category, four at most.
  List<Product> get _offers {
    final pool = [
      ..._products('mostViewed'),
      for (final rail in mapsOf(data?['rails'])) ...mapsOf(rail['products']).map(Product.fromJson),
      ..._products('deals'),
    ];
    final seen = <int>{};
    final offers = pool.where((p) => p.discountPercent > 0 && p.purchasable && seen.add(p.id)).toList()
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    final categories = <String>{};
    return offers.where((p) => categories.add(p.categoryName)).take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: DF.canvas,
      body: Column(
        children: [
          _Header(topInset: top),
          Expanded(
            child: data == null
                ? LoadState(error: error, onRetry: _load, skeleton: const HomeSkeleton())
                : RefreshIndicator(
                    color: DF.primary600,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        const SizedBox(height: 14),
                        _Banners(offers: _offers),
                        _CategoryCircles(tiles: mapsOf((data!['hero'] as Map?)?['tiles'])),
                        const _QuickServices(),
                        const _PurifierCard(),
                        _Deals(products: _products('deals')),
                        for (final rail in mapsOf(data!['rails']))
                          ProductRail(
                            title: '${rail['title']}',
                            href: '${rail['href'] ?? ''}',
                            products: mapsOf(rail['products']).map(Product.fromJson).toList(),
                          ),
                        _MiniRow(title: 'Recently viewed', products: recent),
                        _MiniRow(title: 'Popular this month', products: _products('mostViewed')),
                        _MiniRow(title: 'Just added', products: _products('latest')),
                        const _ExpertCard(),
                        const _TrustStrip(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ header */

/// Greeting, where the customer is (asked when the app opens), help, the
/// cart, and search.
class _Header extends StatelessWidget {
  const _Header({required this.topInset});
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final first = state.user?.name.trim().split(' ').first ?? '';

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/images/favicon.png'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.isEmpty ? 'Welcome to Doctor Fresh' : 'Hello, $first 👋',
                        style: const TextStyle(fontSize: 13, color: DF.ink400, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    _LocationLine(state: state),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Call us',
                onPressed: () => Native.call(),
                icon: const Icon(Icons.support_agent_rounded, color: DF.ink900),
              ),
              CartIconButton(count: state.cartCount),
            ],
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SearchPill(onCanvas: true),
          ),
        ],
      ),
    );
  }
}

/// "📍 Sector 47, Gurgaon 122018 ▾" — tap to look again.
class _LocationLine extends StatelessWidget {
  const _LocationLine({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final status = state.locationStatus;
    final label = state.placeLabel.isNotEmpty
        ? state.placeLabel
        : switch (status) {
            'locating' || 'idle' => 'Finding your location…',
            'denied' => 'Allow location to see your area',
            'off' => 'Turn on location',
            _ => 'Set your location',
          };

    return InkWell(
      onTap: () async {
        await state.locate();
        if (!context.mounted) return;
        final msg = switch (state.locationStatus) {
          'denied' => 'Location permission is off. Allow it for Doctor Fresh in your phone settings.',
          'off' => 'Turn on location (GPS) on your phone and try again.',
          'unavailable' => 'Could not find your location right now.',
          _ => null,
        };
        if (msg != null) toast(context, msg);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, size: 18, color: DF.primary600),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: DF.ink900, letterSpacing: -0.2),
              ),
            ),
            if (status == 'locating')
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: DF.primary600)),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: DF.ink900),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------------- banners */

/// Promo banners that turn by themselves: the page's best offers, then the
/// free water test.
class _Banners extends StatefulWidget {
  const _Banners({required this.offers});
  final List<Product> offers;

  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  final controller = PageController(viewportFraction: 0.92);
  int page = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !controller.hasClients) return;
      final next = (page + 1) % _count;
      controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  /// One product slide, the festive slide, up to two category slides, the water test.
  int get _count => widget.offers.isEmpty ? 1 : 2 + (widget.offers.length - 1).clamp(0, 2) + 1;

  @override
  Widget build(BuildContext context) {
    const palette = [
      [Color(0xFF00608F), Color(0xFF0095DC)], // blue
      [Color(0xFF0B6E4F), Color(0xFF1FA67A)], // green
      [Color(0xFFB4410C), Color(0xFFF08C2E)], // orange
      [Color(0xFF5B2A9E), Color(0xFF8E5BE0)], // purple
      [Color(0xFFB0244B), Color(0xFFE85A7E)], // rose
    ];
    final offers = widget.offers;
    final top = offers.isEmpty ? null : offers.first;
    void openOffers() => AppRouter.push(context, const OffersTab());

    final banners = <Widget>[
      // The one slide that shows a product: the biggest offer on the page.
      if (top != null)
        _Banner(
          colors: palette[0],
          eyebrow: top.categoryName.isEmpty ? 'DEAL OF THE DAY' : 'DEAL OF THE DAY · ${top.categoryName.toUpperCase()}',
          title: top.name.replaceFirst(RegExp(r'^Doctor Fresh\s*-?\s*', caseSensitive: false), ''),
          titleSize: 16,
          details: _ShopDetails(product: top),
          cta: 'Buy now',
          ctaIcon: Icons.shopping_bag_outlined,
          image: Padding(padding: const EdgeInsets.only(top: 18), child: NetImage(top.image)),
          imageBadge: DiscountRibbon(percent: top.discountPercent),
          onTap: () => AppRouter.push(context, ProductScreen(id: top.id, name: top.name)),
          onCta: () => buyNow(context, top),
        ),
      // The rest are offers only, no product.
      if (top != null)
        _Banner(
          colors: palette[2],
          eyebrow: 'FESTIVE OFFERS · LIMITED TIME',
          title: 'Up to ${top.discountPercent}% OFF\non purifiers & RO plants',
          details: const Text('Free installation · Free delivery · Genuine products',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Color(0xD9FFFFFF))),
          cta: 'Shop offers',
          image: _OfferBadge(percent: top.discountPercent, icon: Icons.celebration_rounded),
          plainImage: true,
          onTap: openOffers,
        ),
      for (final (i, p) in offers.skip(1).take(2).indexed)
        _Banner(
          colors: palette[i == 0 ? 1 : 3],
          eyebrow: '${p.categoryName.toUpperCase()} OFFERS',
          title: 'Up to ${p.discountPercent}% OFF\non ${p.categoryName}',
          details: const Text('Best prices of the season, while stocks last',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Color(0xD9FFFFFF))),
          cta: 'Explore offers',
          image: _OfferBadge(percent: p.discountPercent, icon: Icons.local_offer_rounded),
          plainImage: true,
          onTap: openOffers,
        ),
      _Banner(
        colors: const [Color(0xFF063B4C), Color(0xFF0E7490)],
        eyebrow: '100% FREE HOME VISIT',
        title: 'Free Water\nQuality Test',
        cta: 'Book free test',
        image: const Image(image: AssetImage('assets/images/banner17.png'), fit: BoxFit.cover),
        onTap: () => showWaterTestSheet(context),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 184,
          child: PageView(
            controller: controller,
            onPageChanged: (i) => setState(() => page = i),
            children: [
              for (final b in banners) Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: b),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == page ? DF.primary600 : DF.lineStrong,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.colors,
    required this.eyebrow,
    required this.title,
    required this.cta,
    required this.image,
    required this.onTap,
    this.details,
    this.titleSize = 19,
    this.ctaIcon = Icons.arrow_forward_rounded,
    this.onCta,
    this.imageBadge,
    this.plainImage = false,
  });

  /// The slide's gradient, darker first.
  final List<Color> colors;
  final String eyebrow;
  final String title;
  final String cta;
  final Widget image;
  final VoidCallback onTap;

  /// A line under the title (the price and rating on the shop banner).
  final Widget? details;
  final double titleSize;
  final IconData ctaIcon;

  /// The button's own action; the whole banner's otherwise.
  final VoidCallback? onCta;

  /// Sits on the picture's top-left corner (the "% OFF" ribbon).
  final Widget? imageBadge;

  /// The image sits straight on the colour, without the white plate.
  final bool plainImage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.28), offset: const Offset(0, 8), blurRadius: 18, spreadRadius: -8)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
            Positioned(
              right: 10,
              top: 14,
              bottom: 14,
              width: 120,
              child: plainImage
                  ? image
                  : Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(4),
                      child: image,
                    ),
            ),
            if (imageBadge != null)
              Positioned(right: 10, top: 14, width: 120, child: Align(alignment: Alignment.topLeft, child: imageBadge!)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 145, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xD9FFFFFF))),
                  const SizedBox(height: 6),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                  if (details != null) ...[const SizedBox(height: 6), details!],
                  const Spacer(),
                  GestureDetector(
                    onTap: onCta ?? onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cta, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.first)),
                          const SizedBox(width: 4),
                          Icon(ctaIcon, size: 15, color: colors.first),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "22% OFF" in a big white disc, for the offer-only slides.
class _OfferBadge extends StatelessWidget {
  const _OfferBadge({required this.percent, required this.icon});
  final int percent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 6, strokeAlign: BorderSide.strokeAlignOutside),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('UP TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: DF.ink500)),
                Text('$percent%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: DF.ink900, height: 1.05)),
                const Text('OFF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2, color: DF.danger)),
              ],
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: DF.ink900),
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- category circles */

/// The nine home categories as round shortcuts, plus "All".
class _CategoryCircles extends StatelessWidget {
  const _CategoryCircles({required this.tiles});
  final List<Map<String, dynamic>> tiles;

  /// "Water Purifier for Home" → "Water Purifier".
  String _name(String label) {
    final i = label.toLowerCase().lastIndexOf(' for ');
    return i > 0 ? label.substring(0, i) : label;
  }

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final items = tiles.take(7).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Shop by category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth / 4;
            return Wrap(
              runSpacing: 6,
              children: [
                for (final t in items)
                  _circle(
                    width: w,
                    label: _name('${t['label']}'),
                    child: NetImage('${t['image'] ?? ''}'),
                    onTap: () => AppRouter.open(context, '${t['href']}'),
                  ),
                _circle(
                  width: w,
                  label: 'View all',
                  child: const Icon(Icons.apps_rounded, color: DF.primary600, size: 28),
                  onTap: () => AppTabs.current.value = AppTabs.categories,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _circle({required double width, required String label, required Widget child, required VoidCallback onTap}) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                child: ClipOval(child: child),
              ),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DF.ink700, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------- quick services */

class _QuickServices extends StatelessWidget {
  const _QuickServices();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.build_circle_rounded, 'Repair &\nService', DF.primary600, () => AppTabs.current.value = AppTabs.services),
      (
        Icons.home_repair_service_rounded,
        'Install /\nUninstall',
        DF.primary600,
        () => AppRouter.open(context, '/water-purifier-installation')
      ),
      (Icons.event_repeat_rounded, 'AMC\nPlans', DF.primary600, () => AppRouter.open(context, '/water-purifier-amc')),
      (Icons.science_rounded, 'Free Water\nTest', DF.primary600, () => showWaterTestSheet(context)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Water purifier services', size: 18),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: item.$4,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        child: Column(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(12)),
                              child: Icon(item.$1, color: item.$3, size: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(item.$2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DF.ink700, height: 1.2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ my purifier */

/// The customer's own purifier: its filter health when added, an invitation
/// to add it when not.
class _PurifierCard extends StatelessWidget {
  const _PurifierCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Purifier?>(
      valueListenable: PurifierStore.instance.current,
      builder: (context, p, _) {
        final days = p == null ? 0 : Purifier.daysUntil(p.nextService);
        final left = p?.serviceLeft ?? 0;
        final tone = left > 0.35
            ? DF.success
            : left > 0.1
                ? DF.warning
                : DF.danger;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => AppRouter.push(context, const PurifierScreen()),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.water_drop_rounded, color: DF.primary700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p == null ? 'Track my purifier' : 'My ${p.brand.isEmpty ? 'purifier' : p.brand}',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DF.ink900)),
                          const SizedBox(height: 3),
                          if (p == null)
                            const Text('Filter health and service reminders', style: TextStyle(fontSize: 12.5, color: DF.ink400))
                          else ...[
                            Text(
                              days < 0 ? 'Service overdue by ${-days} days' : days == 0 ? 'Service due today' : 'Next service in $days days',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: days <= 3 ? DF.danger : DF.ink500),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: left, minHeight: 5, color: tone, backgroundColor: DF.line),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(p == null ? Icons.add_circle_outline_rounded : Icons.chevron_right_rounded, color: DF.primary600),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ------------------------------------------------------------------- deals */

class _Deals extends StatelessWidget {
  const _Deals({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final w = (MediaQuery.of(context).size.width - 16) / 2.25;
    return Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.only(top: 16, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: DF.primary600, size: 21),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Today’s Commercial Deals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DF.ink900)),
                ),
                InkWell(
                  onTap: () => AppRouter.push(context, const OffersTab()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View all', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.primary700)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 15, color: DF.primary700),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: w, child: DealCard(product: products[i])),
            ),
          ),
        ],
      ),
    );
  }
}

/// "₹14,000 ₹16,500 15% off" and "★ 4.8 (29) · Free installation" on the
/// shop banner.
class _ShopDetails extends StatelessWidget {
  const _ShopDetails({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    const light = Color(0xCCFFFFFF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(p.price > 0 ? formatPrice(p.price) : 'Price on request',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            if (p.mrp > p.price) ...[
              const SizedBox(width: 6),
              Text(formatPrice(p.mrp),
                  style: const TextStyle(fontSize: 12, color: light, decoration: TextDecoration.lineThrough, decorationColor: light)),
              const SizedBox(width: 6),
              Text('${p.discountPercent}% off',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFFE08A))),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 14, color: DF.star),
            const SizedBox(width: 2),
            Text('${(p.rating > 0 ? p.rating : 4.5).toStringAsFixed(1)} (${p.reviewCount})',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: light)),
            const Flexible(
              child: Text('  ·  Free installation',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: light)),
            ),
          ],
        ),
      ],
    );
  }
}

/* -------------------------------------------------------- mini product row */

/// Recently viewed / popular / new: small cards, three or so on screen.
class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.title, required this.products});
  final String title;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SectionTitle(title, size: 18)),
          const SizedBox(height: 10),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = products[i];
                return SizedBox(
                  width: 128,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => AppRouter.push(context, ProductScreen(id: p.id, name: p.name)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 92,
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: DF.stage, borderRadius: BorderRadius.circular(12)),
                              child: NetImage(p.image),
                            ),
                            const SizedBox(height: 6),
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: DF.ink900, height: 1.25)),
                            const Spacer(),
                            Text(p.price > 0 ? formatPrice(p.price) : 'Price on request',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DF.ink900)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------- expert card */

class _ExpertCard extends StatelessWidget {
  const _ExpertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: DF.primary600, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Not sure which purifier suits your water?',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.25)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Free consultation with a Doctor Fresh water expert.',
              style: TextStyle(fontSize: 13.5, color: DF.ink400, height: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: PrimaryButton('Call now', icon: Icons.call_rounded, height: 44, onPressed: () => Native.call())),
              const SizedBox(width: 10),
              Expanded(
                child: OutlineButton('WhatsApp', icon: Icons.chat_rounded, height: 44, onPressed: () => Native.whatsapp()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.local_shipping_outlined, 'Free\nShipping'),
      (Icons.handyman_outlined, 'Free\nInstallation'),
      (Icons.verified_outlined, 'Genuine\nParts'),
      (Icons.schedule_rounded, 'Service in\n24 Hours'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Column(
                children: [
                  Icon(item.$1, color: DF.primary600, size: 24),
                  const SizedBox(height: 6),
                  Text(item.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: DF.ink500, fontWeight: FontWeight.w500, height: 1.25)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- water test form */

/// "Book Free Water Test" — POST /api/forms/lead, as the home page's form.
Future<void> showWaterTestSheet(BuildContext context) {
  return showDFSheet(
    context,
    title: 'Free Water Test',
    subtitle: 'Know what’s in your water before you buy a purifier — tested at home by a Doctor Fresh analyst.',
    builder: (_) => const _WaterTestForm(),
  );
}

class _WaterTestForm extends StatefulWidget {
  const _WaterTestForm();

  @override
  State<_WaterTestForm> createState() => _WaterTestFormState();
}

class _WaterTestFormState extends State<_WaterTestForm> {
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  bool busy = false;
  bool done = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final user = AppScope.read(context).user;
    if (user != null) {
      name.text = user.name;
      mobile.text = user.mobile;
      email.text = user.email;
    }
  }

  Future<void> _send() async {
    final m = normaliseMobile(mobile.text);
    if (name.text.trim().length < 2) return setState(() => error = 'Please enter your name.');
    if (!emailPattern.hasMatch(email.text.trim())) return setState(() => error = 'Please enter a valid email.');
    if (!mobilePattern.hasMatch(m)) return setState(() => error = 'Please enter a valid 10 digit mobile number.');
    setState(() {
      busy = true;
      error = null;
    });
    final res = await Api.instance.post('/api/forms/lead', {
      'name': name.text.trim(),
      'email': email.text.trim(),
      'mobile': m,
      'enquiry_type': 'Book Free Water Test',
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      done = res.ok;
      error = res.ok ? null : res.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (done) return const SuccessNote('Thank you — our water analyst will call you to schedule the free test.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in const ['TDS', 'PH', 'Hardness', 'ORP', 'Turbidity', 'Color/Smell'])
              Chip(
                label: Text(p, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DF.primary700)),
                backgroundColor: DF.primary50,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 14),
        DFField(label: 'Name', controller: name, required: true),
        DFField(label: 'Email', controller: email, required: true, keyboard: TextInputType.emailAddress),
        DFField(
            label: 'Your 10 Digit Number',
            controller: mobile,
            required: true,
            keyboard: TextInputType.phone,
            digitsOnly: true,
            maxLength: 10),
        if (error != null) ErrorNote(error!),
        PrimaryButton('Book Free Water Test', loading: busy, onPressed: _send),
      ],
    );
  }
}
