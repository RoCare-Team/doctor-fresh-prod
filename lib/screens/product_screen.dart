import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/forms.dart';
import '../widgets/html_view.dart';
import '../widgets/net_image.dart';
import '../widgets/product_card.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';
import '../widgets/skeleton.dart';
import 'account_screens.dart';
import 'cart_screens.dart';

/// The product page (app/(shop)/product/[slug]/[id]/page.jsx, from
/// GET /api/mobile/product/<id>) laid out as a shopping app: the gallery edge
/// to edge, Share and Save in the app bar, then white sections on the grey
/// canvas — name, rating and price with the quantity; delivery check;
/// perks; how it works; details tabs; reviews; FAQs; "Offers for you"; and
/// related products. Add to Cart / Buy Now stay on the bottom bar.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.id, this.name});
  final int id;
  final String? name;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Map<String, dynamic>? data;
  String? error;
  int qty = 1;
  final reviewsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
    // Records the view against this visitor's cookie, for the home page (RecentlyViewed.jsx).
    Api.instance.post('/api/recently-viewed', {'id': widget.id});
  }

  Future<void> _load() async {
    setState(() => error = null);
    final res = await Api.instance.get('/api/mobile/product/${widget.id}');
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        data = res.map;
      } else {
        error = res.error;
      }
    });
  }

  Product get product => Product.fromJson(data?['product']);

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return DFScaffold(title: widget.name ?? '', body: LoadState(error: error, onRetry: _load, skeleton: const ProductDetailSkeleton()));
    }
    final p = product;
    final related = mapsOf(data!['related']).map(Product.fromJson).toList();
    final specs = p.specifications.where((s) => str(s['value']).isNotEmpty && str(s['value']) != '-').toList();

    final state = AppScope.of(context);
    final saved = state.saved(p.id);

    return DFScaffold(
      title: '',
      actions: [
        IconButton(
          tooltip: 'Share',
          onPressed: () => Native.share(p.webUrl, context: context),
          icon: const Icon(Icons.share_outlined, color: DF.ink900, size: 22),
        ),
        IconButton(
          tooltip: saved ? 'Saved' : 'Save',
          onPressed: () async {
            final ok = await state.toggleWishlist(p.id);
            if (!ok && context.mounted) AppRouter.push(context, const AuthScreen());
          },
          icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? DF.danger : DF.ink900, size: 22),
        ),
      ],
      // Add to Cart / Buy Now live on the bottom bar, as in a shopping app.
      bottomBar: p.purchasable ? _MobileBuyBar(product: p, qty: qty) : null,
      body: RefreshIndicator(
        color: DF.primary600,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(color: Colors.white, padding: const EdgeInsets.only(bottom: 14), child: _Gallery(product: p)),

            // name, rating, price, quantity
            _Section(
              top: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (p.categoryName.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => AppRouter.open(context, p.categoryHref),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(999)),
                          child:
                              Text(p.categoryName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DF.primary700)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.3)),
                  ..._summary(p),
                  const SizedBox(height: 10),
                  _ratingRow(p),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _PriceBlock(product: p),
                  const SizedBox(height: 14),
                  _buyActions(p),
                ],
              ),
            ),

            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DeliveryCheck(),
                  const SizedBox(height: 14),
                  _Perks(specs: specs),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _OutlinedLink(icon: Icons.phone_outlined, label: 'Call expert', onTap: () => Native.call())),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OutlinedLink(
                          icon: Icons.description_outlined,
                          label: 'Brochure',
                          onTap: () => showQuotationSheet(context, p.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_purificationSteps(p.name).length >= 3) _Section(child: _HowItWorks(name: p.name)),
            _Section(child: _Tabs(product: p, specs: specs)),
            _Section(child: KeyedSubtree(key: reviewsKey, child: _Reviews(product: p, onSaved: _load))),
            if (p.faqs.isNotEmpty)
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Frequently asked questions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                    const SizedBox(height: 12),
                    _Accordion(items: p.faqs),
                  ],
                ),
              ),

            if (related.isNotEmpty) ProductRail(title: 'Related products', products: related, href: p.categoryHref),
          ],
        ),
      ),
    );
  }

  /// One line under the name: for a purifier, what its name says it does;
  /// otherwise the first sentence of the description.
  List<Widget> _summary(Product p) {
    final household = RegExp(r'water-purifier|water-ionizer').hasMatch(p.categoryHref);
    final tech = _technologies(p.name).map((t) => t.id.toUpperCase()).where((t) => t.length <= 3).toList();
    final summary = household && tech.isNotEmpty
        ? 'Advanced ${tech.join(' + ')} purification for safe, healthy and great tasting water.'
        : _firstSentence(p.metaDescription);
    if (summary.isEmpty) return const [];
    return [
      const SizedBox(height: 6),
      Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, color: DF.ink500, height: 1.45)),
    ];
  }

  Widget _ratingRow(Product p) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (p.rating > 0) RatingChip(p.rating, size: 12),
        if (p.rating > 0 && p.reviewCount > 0)
          GestureDetector(
            onTap: () {
              final ctx = reviewsKey.currentContext;
              if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350));
            },
            child: Text('${p.reviewCount} Ratings',
                style: const TextStyle(fontSize: 14, color: DF.ink400, decoration: TextDecoration.underline, decorationColor: DF.ink300)),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: p.inStock ? DF.success : DF.danger, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(p.inStock ? 'In Stock' : 'Currently out of stock',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.inStock ? DF.success : DF.danger)),
          ],
        ),
      ],
    );
  }

  /// AddToCartButtons.jsx: the quantity here, Add to Cart and Buy Now on the
  /// bottom bar; a product priced on request offers a call or a quotation.
  Widget _buyActions(Product p) {
    if (!p.purchasable) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          PrimaryButton('Call to Water Expert', onPressed: () => Native.call()),
          OutlineButton('Request a quotation', onPressed: () => AppRouter.open(context, '/contact')),
        ],
      );
    }
    // The bottom bar adds this many.
    return Row(
      children: [
        const Text('Quantity', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink700)),
        const Spacer(),
        QtyStepper(value: qty, max: p.maxQty, height: 38, onChanged: (v) => setState(() => qty = v)),
      ],
    );
  }
}

/// "Add to Cart" in green outline, turning solid green "Added" once the
/// product is in the basket; a second tap opens the basket.
class _CartButton extends StatelessWidget {
  const _CartButton({
    required this.added,
    required this.onTap,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.idleColor,
    this.borderWidth = 1.5,
  });

  final bool added;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;
  final Color idleColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: added ? Colors.white : idleColor,
          backgroundColor: added ? DF.primary600 : Colors.white,
          side: BorderSide(color: added ? DF.primary600 : idleColor, width: borderWidth),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(added ? Icons.check : Icons.shopping_cart_outlined, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(added ? 'Added' : 'Add to Cart', overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------------- gallery */

/// ProductGallery.jsx on a phone: a swipe deck with the discount and badges
/// on the left, "1/3" on the right, a thumbnail of every photo under it and
/// the demo video link.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.product});
  final Product product;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final pages = PageController();
  int slide = 0;

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void _go(int i) => pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = p.images.isNotEmpty ? p.images : [p.image];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          child: AspectRatio(
            aspectRatio: 1.05,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: pages,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => slide = i),
                    itemBuilder: (_, i) => Padding(padding: const EdgeInsets.fromLTRB(24, 40, 24, 12), child: NetImage(images[i])),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 12,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.discountPercent > 0)
                          Padding(padding: const EdgeInsets.only(bottom: 6), child: DiscountRibbon(percent: p.discountPercent)),
                        for (final b in p.badges)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Color(0x400F172A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: -4)],
                            ),
                            child: Text(b, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DF.primary700)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(999)),
                      child: Text('${slide + 1}/${images.length}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: DF.ink500)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Every photo as a small thumbnail under the big one; tap to show it.
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _go(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i == slide ? DF.primary600 : DF.line, width: i == slide ? 2 : 1),
                  ),
                  child: NetImage(images[i]),
                ),
              ),
            ),
          ),
        ],
        if (p.videoUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => Native.open(p.videoUrl, context: context),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 15, color: DF.primary700),
                    SizedBox(width: 4),
                    Text('Watch demo video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.primary700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/* ------------------------------------------------------------------- price */

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return p.price > 0
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (p.discountPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: DF.discountBg, borderRadius: BorderRadius.circular(8)),
                      child: Text('-${p.discountPercent}%',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: DF.primary700)),
                    ),
                  Text(formatPrice(p.price),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: DF.ink900, height: 1, letterSpacing: -0.5)),
                  if (p.unit.isNotEmpty) Text(p.unit, style: const TextStyle(fontSize: 13, color: DF.ink400)),
                ],
              ),
              if (p.mrp > p.price) ...[
                const SizedBox(height: 8),
                Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 15, color: DF.ink400),
                  children: [
                    const TextSpan(text: 'M.R.P. '),
                    TextSpan(text: formatPrice(p.mrp), style: const TextStyle(decoration: TextDecoration.lineThrough)),
                    TextSpan(
                      text: '  (Save ${formatPrice(p.mrp - p.price)})',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: DF.primary700),
                    ),
                  ],
                )),
              ],
              const SizedBox(height: 4),
              const Text('Inclusive of all taxes · Free shipping across India', style: TextStyle(fontSize: 13.5, color: DF.ink400)),
            ],
          )
        : const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Price on request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: DF.ink900)),
              SizedBox(height: 4),
              Text('Industrial and commercial systems are quoted after a site requirement check.',
                  style: TextStyle(fontSize: 14, color: DF.ink400)),
            ],
          );
  }
}

/* ---------------------------------------------------------- delivery check */

/// DeliveryCheck.jsx — the pin code is checked against /api/pincode and
/// remembered on the device under `df_pincode`.
class _DeliveryCheck extends StatefulWidget {
  const _DeliveryCheck();

  @override
  State<_DeliveryCheck> createState() => _DeliveryCheckState();
}

class _DeliveryCheckState extends State<_DeliveryCheck> {
  static const _storeKey = 'df_pincode';
  final pin = TextEditingController();
  String status = 'idle'; // idle | loading | done | error
  String message = '';
  String city = '';
  String region = '';

  @override
  void initState() {
    super.initState();
    final saved = Store.instance.get<String>(_storeKey) ?? '';
    if (RegExp(r'^\d{6}$').hasMatch(saved)) {
      pin.text = saved;
      _check(saved);
    }
  }

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> _check(String value) async {
    if (!pinPattern.hasMatch(value)) {
      setState(() {
        status = 'error';
        message = 'Enter a 6-digit pin code';
      });
      return;
    }
    setState(() => status = 'loading');
    final res = await Api.instance.get('/api/pincode/$value');
    if (!mounted) return;
    if (res.networkError || (res.status >= 500)) {
      setState(() {
        status = 'error';
        message = 'Could not check right now — please try again';
      });
      return;
    }
    if (!res.ok) {
      setState(() {
        status = 'error';
        message = 'We could not find this pin code';
      });
      return;
    }
    Store.instance.set(_storeKey, value);
    setState(() {
      status = 'done';
      city = str(res.map['city']);
      region = str(res.map['state']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [
          Icon(Icons.local_shipping_outlined, size: 20, color: DF.primary600),
          SizedBox(width: 8),
          Text('Check delivery & installation', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900)),
        ]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: pin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  onChanged: (_) => setState(() => status = 'idle'),
                  onSubmitted: _check,
                  style: const TextStyle(fontSize: 14.5, color: DF.ink900),
                  decoration: InputDecoration(
                    hintText: 'Enter pin code',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: DF.lineStrong)),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: DF.lineStrong)),
                    focusedBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: DF.primary500)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: status == 'loading' ? null : () => _check(pin.text),
                style: FilledButton.styleFrom(
                  backgroundColor: DF.primary600,
                  disabledBackgroundColor: DF.primary600.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (status == 'loading') ...[
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 6),
                  ],
                  const Text('Check'),
                ]),
              ),
            ),
          ],
        ),
        if (status == 'done') ...[
          const SizedBox(height: 8),
          Text.rich(TextSpan(
            style: const TextStyle(fontSize: 13, color: DF.ink500, height: 1.4),
            children: [
              TextSpan(text: 'Delivers to $city, $region', style: const TextStyle(fontWeight: FontWeight.w500, color: DF.success)),
              const TextSpan(text: ' — free shipping and free installation by a certified technician.'),
            ],
          )),
        ],
        if (status == 'error') ...[
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13, color: DF.danger)),
        ],
      ],
    );
  }
}

/// "Free Installation*" and the catalogue's warranty, beside the delivery check.
class _Perks extends StatelessWidget {
  const _Perks({required this.specs});
  final List<Map<String, dynamic>> specs;

  @override
  Widget build(BuildContext context) {
    // "1 Year Onsite Warranty, 4 Year Service…" → "1 Year Onsite".
    final w = specs.where((s) => RegExp('warranty', caseSensitive: false).hasMatch(str(s['label']))).firstOrNull;
    final warranty = str(w?['value']).split(RegExp(r'[,;]')).first.replaceFirst(RegExp('warranty', caseSensitive: false), '').trim();

    Widget item(IconData icon, String text) => Expanded(
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: DF.primary600),
              ),
              const SizedBox(height: 6),
              Text(text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: DF.ink700, height: 1.25)),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(Icons.local_shipping_outlined, 'Free\nDelivery'),
        item(Icons.build_outlined, 'Free\nInstallation*'),
        item(Icons.verified_user_outlined, warranty.isNotEmpty ? '$warranty\nWarranty' : 'Warranty\nSupport'),
        item(Icons.workspace_premium_outlined, 'Genuine\nProduct'),
      ],
    );
  }
}

class _OutlinedLink extends StatelessWidget {
  const _OutlinedLink({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: DF.line)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: DF.ink700),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DF.ink700)),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ how it works */

/// One technology a purifier's name can claim (lib/product-tech.js TECH).
class _Tech {
  const _Tech(this.id, this.match, this.stepTitle, this.stepNote);
  final String id;
  final String match;
  final String stepTitle;
  final String stepNote;
}

const _techList = [
  _Tech('ro', r'\bRO\b', 'RO Membrane', 'Pushes water through a fine membrane, leaving dissolved salts behind'),
  _Tech('uv', r'\bUV\b', 'UV Purification', 'Ultraviolet light kills bacteria and harmful microorganisms'),
  _Tech('uf', r'\bUF\b', 'UF Filtration', 'Removes visible dirt, mud and cysts from the water'),
  _Tech('tds', r'TDS', 'TDS Control', 'Balances the minerals so the water tastes right'),
  _Tech('alkaline', r'alkaline', 'Alkaline Boost', 'Brings the water back to its natural pH'),
  _Tech('copper', r'copper', 'Copper Infusion', 'Adds the benefits of water stored in copper'),
  _Tech('mineral', r'\bME\b|mineral', 'Mineral Enrichment', 'Returns the essential minerals the filters took out'),
];

/// The technologies named in a product's title, in the order they are listed.
List<_Tech> _technologies(String name) => _techList.where((t) => RegExp(t.match, caseSensitive: false).hasMatch(name)).toList();

/// Tap in, each stage the name claims (four at most), clean water out —
/// nothing when the name claims no stage (`purificationSteps`).
List<(String, String)> _purificationSteps(String name) {
  final stages = _technologies(name).map((t) => (t.stepTitle, t.stepNote)).toList();
  if (stages.isEmpty) return const [];
  return [
    ('Tap Water In', 'Water from your supply enters the purifier'),
    ...stages.take(4),
    ('Clean Water Out', 'Safe, healthy and great-tasting water for your family'),
  ];
}

String _firstSentence(String text) {
  final plain = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final m = RegExp(r'[.!?](\s|$)').firstMatch(plain);
  return m != null && m.start > 0 ? plain.substring(0, m.start + 1) : plain;
}

/// The icon and tint of each stage (HowItWorks.jsx STAGE_LOOK).
(IconData, List<Color>, Color) _stageLook(String title) {
  bool has(String re) => RegExp(re, caseSensitive: false).hasMatch(title);
  if (has('tap')) return (Icons.water_drop_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has(r'\bRO\b')) return (Icons.layers_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('UV')) return (Icons.wb_sunny_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('UF|filtration')) return (Icons.filter_alt_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('TDS')) return (Icons.speed, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('alkaline')) return (Icons.auto_awesome_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('copper')) return (Icons.eco_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('mineral')) return (Icons.diamond_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  if (has('clean|out')) return (Icons.local_drink_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
  return (Icons.verified_user_outlined, const [DF.primary50, Color(0xFFF7FBFE)], DF.primary600);
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final steps = _purificationSteps(name);
    if (steps.length < 3) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('How it works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
        const SizedBox(height: 2),
        const Text('Stage by stage, how this product cleans your water.', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: steps.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 34),
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: DF.primary300),
            ),
            itemBuilder: (_, i) => _step(steps[i], i),
          ),
        ),
      ],
    );
  }

  /// A round icon with its number, and the stage's name under it.
  Widget _step((String, String) step, int i) {
    final (icon, _, color) = _stageLook(step.$1);
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: color),
              ),
              Positioned(
                right: -4,
                top: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: DF.primary600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(step.$1,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DF.ink700, height: 1.2)),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------- tabs */

/// ProductTabs.jsx — only the tabs that have something in them.
class _Tabs extends StatefulWidget {
  const _Tabs({required this.product, required this.specs});
  final Product product;
  final List<Map<String, dynamic>> specs;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  String? active;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    void link(String href) => AppRouter.open(context, href);

    final tabs = <(String, String, Widget)>[
      if (p.descriptionHtml.isNotEmpty) ('description', 'Description', HtmlView(p.descriptionHtml, onLink: link)),
      if (p.videoUrl.isNotEmpty) ('video', 'Video', _video(p)),
      if (widget.specs.isNotEmpty) ('specifications', 'Specifications', _specTable(widget.specs)),
      if (p.attributes.isNotEmpty) ('features', 'Attribute', _attributes(p.attributes)),
      if (p.installationHtml.isNotEmpty)
        (
          'installation',
          'Installation & Service',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HtmlView(p.installationHtml, onLink: link),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final (label, href) in const [
                    ('Installation / Uninstallation →', '/water-purifier-installation'),
                    ('RO repair & service →', '/water-purifier-service'),
                    ('AMC plans →', '/water-purifier-amc'),
                  ])
                    GestureDetector(
                      onTap: () => link(href),
                      child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: DF.primary700)),
                    ),
                ],
              ),
            ],
          ),
        ),
      if (p.shippingHtml.isNotEmpty) ('shipping', 'Billing & Shipping', HtmlView(p.shippingHtml, onLink: link)),
    ];
    if (tabs.isEmpty) return const SizedBox.shrink();
    final current = tabs.firstWhere((t) => t.$1 == active, orElse: () => tabs.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DF.line))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in tabs)
                  InkWell(
                    onTap: () => setState(() => active = t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: t.$1 == current.$1 ? DF.primary500 : Colors.transparent, width: 2),
                        ),
                      ),
                      child: Text(t.$2,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: t.$1 == current.$1 ? DF.primary700 : DF.ink400,
                          )),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        current.$3,
      ],
    );
  }

  Widget _video(Product p) {
    return GestureDetector(
      onTap: () => Native.open(p.videoUrl, context: context),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, size: 34, color: DF.primary600),
              ),
              const SizedBox(height: 10),
              Text('${p.name} video',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _specTable(List<Map<String, dynamic>> specs) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: DF.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, s) in specs.indexed)
            Container(
              decoration: BoxDecoration(border: i == specs.length - 1 ? null : const Border(bottom: BorderSide(color: DF.line))),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: DF.surfaceMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(str(s['label']),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.ink700, height: 1.3)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(plainText(str(s['value'])), style: const TextStyle(fontSize: 13, color: DF.ink500, height: 1.3)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attributes(List<Map<String, dynamic>> attrs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in attrs)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(a['label']).toUpperCase(), style: const TextStyle(fontSize: 13, letterSpacing: 0.4, color: DF.ink300)),
                const SizedBox(height: 2),
                Text(((a['values'] as List?) ?? const []).map((e) => '$e').join(', '),
                    style: const TextStyle(fontSize: 14.5, color: DF.ink700)),
              ],
            ),
          ),
      ],
    );
  }
}

/* ----------------------------------------------------------------- reviews */

/// "Ratings & reviews": ProductReviews.jsx then ReviewForm.jsx.
class _Reviews extends StatelessWidget {
  const _Reviews({required this.product, required this.onSaved});
  final Product product;
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final reviews = p.reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ratings & reviews', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
        const SizedBox(height: 20),
        if (p.rating > 0 || reviews.isNotEmpty) ...[
          if (p.rating > 0) ...[_summary(p), const SizedBox(height: 24)],
          if (reviews.isNotEmpty)
            for (final r in reviews) _card(r)
          else
            const Text('No written reviews yet for this product.', style: TextStyle(fontSize: 14.5, color: DF.ink400)),
        ] else
          const Text('No reviews yet — be the first to rate this product.', style: TextStyle(fontSize: 14.5, color: DF.ink400)),
        const SizedBox(height: 24),
        // The form opens in a sheet, so the page stays short.
        Align(
          alignment: Alignment.centerLeft,
          child: OutlineButton(
            'Write a review',
            icon: Icons.rate_review_outlined,
            height: 42,
            fontSize: 14,
            onPressed: () => showDFSheet(context, title: 'Write a review', builder: (_) => _ReviewForm(productId: p.id, onSaved: onSaved)),
          ),
        ),
      ],
    );
  }

  Widget _summary(Product p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: DF.surfaceMuted, borderRadius: BorderRadius.circular(14), border: Border.all(color: DF.line)),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(p.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: DF.ink900)),
                  const SizedBox(width: 6),
                  const Text('/ 5', style: TextStyle(fontSize: 14, color: DF.ink400)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(i <= p.rating.round() ? Icons.star_rounded : Icons.star_border_rounded, size: 15, color: DF.warning),
                ],
              ),
            ],
          ),
          if (p.reviewCount > 0)
            Text.rich(TextSpan(
              style: const TextStyle(fontSize: 14.5, color: DF.ink500),
              children: [
                const TextSpan(text: 'Based on '),
                TextSpan(text: '${p.reviewCount}', style: const TextStyle(fontWeight: FontWeight.w500, color: DF.ink900)),
                const TextSpan(text: ' customer reviews'),
              ],
            )),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    return DFCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RatingChip(toNum(r['rating']), size: 12),
              if (str(r['title']).isNotEmpty)
                Text(str(r['title']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: DF.ink900)),
            ],
          ),
          if (str(r['body']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(str(r['body']), style: const TextStyle(fontSize: 14.5, color: DF.ink500, height: 1.6)),
          ],
          const SizedBox(height: 8),
          Text(str(r['author']), style: const TextStyle(fontSize: 13.5, color: DF.ink400)),
        ],
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.productId, required this.onSaved});
  final int productId;
  final Future<void> Function() onSaved;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final comment = TextEditingController();
  int rating = 0;
  String status = 'idle'; // idle | sending | done | error
  String error = '';

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (rating == 0) {
      setState(() {
        error = 'Choose a star rating first.';
        status = 'error';
      });
      return;
    }
    setState(() {
      status = 'sending';
      error = '';
    });
    final res = await Api.instance.post('/api/reviews', {
      'productId': widget.productId,
      'rating': rating,
      'comment': comment.text,
    });
    if (!mounted) return;
    if (res.needsSignIn) {
      setState(() => status = 'idle');
      AppRouter.push(context, const AuthScreen());
      return;
    }
    if (!res.ok) {
      setState(() {
        error = res.map['error'] is String ? res.error : 'Could not save your review.';
        status = 'error';
      });
      return;
    }
    comment.clear();
    setState(() {
      status = 'done';
      rating = 0;
    });
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var n = 1; n <= 5; n++)
              GestureDetector(
                onTap: () => setState(() => rating = n),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(n <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 28, color: n <= rating ? DF.warning : DF.ink300),
                ),
              ),
            if (rating > 0) ...[
              const SizedBox(width: 8),
              Text('$rating of 5', style: const TextStyle(fontSize: 14, color: DF.ink500)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: comment,
          maxLines: 3,
          style: const TextStyle(fontSize: 15, color: DF.ink900),
          decoration: const InputDecoration(hintText: 'What did you think of this product? (optional)'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(status == 'sending' ? 'Saving…' : 'Submit review', onPressed: status == 'sending' ? null : _submit),
        if (status == 'done') ...[
          const SizedBox(height: 12),
          const SuccessNote('Thank you — your review has been saved.'),
        ],
        if (status == 'error') ...[
          const SizedBox(height: 12),
          ErrorNote(error),
        ],
      ],
    );
  }
}

/* --------------------------------------------------------------------- FAQ */

/// Accordion.jsx — the first answer open, one at a time.
class _Accordion extends StatefulWidget {
  const _Accordion({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  int open = 0;

  @override
  Widget build(BuildContext context) {
    return DFCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in widget.items.indexed) ...[
            if (i > 0) const Divider(),
            InkWell(
              onTap: () => setState(() => open = open == i ? -1 : i),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                          Text(str(item['question']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: DF.ink900)),
                    ),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(open == i ? Icons.remove : Icons.add, size: 18, color: DF.primary700),
                    ),
                  ],
                ),
              ),
            ),
            if (open == i)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: str(item['answerHtml']).isNotEmpty
                    ? HtmlView(str(item['answerHtml']), onLink: (h) => AppRouter.open(context, h))
                    : Text(str(item['answer']), style: DF.body),
              ),
          ],
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- mobile buy bar */

/// MobileBuyBar.jsx — price, Add to Cart and Buy Now on the bottom edge.
class _MobileBuyBar extends StatelessWidget {
  const _MobileBuyBar({required this.product, this.qty = 1});
  final Product product;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final state = AppScope.of(context);
    final added = state.inCart(p.id);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DF.line)),
        boxShadow: [BoxShadow(color: Color(0x400F172A), offset: Offset(0, -6), blurRadius: 20, spreadRadius: -12)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Flexible(
                flex: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatPrice(p.price),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.2)),
                    if (p.mrp > p.price)
                      Text.rich(TextSpan(
                        style: const TextStyle(fontSize: 11.5, color: DF.ink400, height: 1.2),
                        children: [
                          TextSpan(text: formatPrice(p.mrp), style: const TextStyle(decoration: TextDecoration.lineThrough)),
                          if (p.discountPercent > 0)
                            TextSpan(
                                text: ' ${p.discountPercent}% off',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: DF.primary700)),
                        ],
                      )),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CartButton(
                  added: added,
                  height: 46,
                  radius: 12,
                  fontSize: 14,
                  idleColor: DF.primary600,
                  borderWidth: 1,
                  onTap: () => added ? AppRouter.push(context, const CartScreen()) : state.addToCart(p.toCartLine(qty)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton('Buy Now',
                    height: 46, radius: 12, fontSize: 14.5, color: DF.primary600, onPressed: () => buyNow(context, p, qty: qty)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One white block of the page on the grey canvas, 8px apart.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.top = 8});
  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: top),
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: child,
      );
}
