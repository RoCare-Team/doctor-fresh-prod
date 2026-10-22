import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../router.dart';
import '../screens/account_screens.dart';
import '../screens/cart_screens.dart';
import '../screens/product_screen.dart';
import '../state/app_state.dart';
import 'forms.dart';
import 'net_image.dart';
import 'ui.dart';

/// "Buy Now": the item goes in the cart, then checkout — after signing in
/// when needed (AddToCartButtons.jsx).
Future<void> buyNow(BuildContext context, Product p, {int qty = 1}) async {
  final state = AppScope.read(context);
  state.addToCart(p.toCartLine(qty));
  if (!state.signedIn) {
    final ok = await showSignInPrompt(context);
    if (!ok || !context.mounted) return;
  }
  if (context.mounted) AppRouter.push(context, const CheckoutScreen());
}

/// The heart on cards and the product page. Signed out, it goes to sign in.
class WishlistButton extends StatelessWidget {
  const WishlistButton({super.key, required this.productId, this.size = 28});
  final int productId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.saved(productId);
    return GestureDetector(
      onTap: () async {
        final ok = await state.toggleWishlist(productId);
        if (!ok && context.mounted) AppRouter.push(context, const AuthScreen());
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A0F172A), blurRadius: 6)]),
        child: Icon(saved ? Icons.favorite : Icons.favorite_border, size: size * 0.55, color: saved ? DF.danger : DF.ink300),
      ),
    );
  }
}

/// "16% OFF" on a blue ribbon that comes in from the card's edge and ends in
/// a notch — the offer reads at a glance without a second colour.
class DiscountRibbon extends StatelessWidget {
  const DiscountRibbon({super.key, required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _RibbonClipper(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 16, 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [DF.primary700, DF.primary400], begin: Alignment.centerLeft, end: Alignment.centerRight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer_rounded, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Text('$percent% OFF',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

/// Square on the left (against the card edge), a V cut on the right.
class _RibbonClipper extends CustomClipper<Path> {
  const _RibbonClipper();

  @override
  Path getClip(Size size) {
    const notch = 7.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - notch, size.height / 2)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_RibbonClipper oldClipper) => false;
}

/// The catalogue card (components/products/ProductCard.jsx, mobile layout).
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final state = AppScope.of(context);
    final inCart = state.inCart(p.id);

    return GestureDetector(
      onTap: () => AppRouter.push(context, ProductScreen(id: p.id, name: p.name)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: DF.productShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      // The picture starts under the offer ribbon, not behind it.
                      padding: EdgeInsets.fromLTRB(10, p.discountPercent > 0 ? 30 : 10, 10, 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: NetImage(p.image),
                    ),
                  ),
                  if (p.discountPercent > 0) Positioned(left: -8, top: 2, child: DiscountRibbon(percent: p.discountPercent)),
                  Positioned(right: 0, top: 0, child: WishlistButton(productId: p.id)),
                  Positioned(left: 0, bottom: 0, child: RatingChip(p.rating > 0 ? p.rating : 4.5, size: 10.5)),
                  if (!p.inStock)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: DF.ink900.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                        child:
                            const Text('Out of stock', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.ink900, height: 1.35)),
            ),
            const SizedBox(height: 6),
            SizedBox(height: 38, child: PriceLine(price: p.price, mrp: p.mrp, discount: p.discountPercent)),
            const SizedBox(height: 8),
            if (p.purchasable)
              Row(
                children: [
                  // A soft (tonal) button keeps the grid light; the colour is
                  // saved for the product page's own Buy Now.
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: FilledButton(
                        onPressed: () => buyNow(context, p),
                        style: FilledButton.styleFrom(
                          backgroundColor: DF.primary100,
                          foregroundColor: DF.primary700,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Buy Now'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () => inCart ? AppRouter.push(context, const CartScreen()) : state.addToCart(p.toCartLine()),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: inCart ? DF.primary50 : Colors.white,
                        side: BorderSide(color: inCart ? DF.primary300 : DF.line, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Icon(inCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded, size: 18, color: DF.primary700),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlineButton('Enquire now',
                    height: 38, radius: 8, fontSize: 13.5, onPressed: () => AppRouter.push(context, ProductScreen(id: p.id, name: p.name))),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 2-column grid of cards (ProductGrid.jsx). Not scrollable itself.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 20,
        children: [for (final p in products) SizedBox(width: w, child: ProductCard(product: p))],
      );
    });
  }
}

/// A horizontal rail, two cards per screen (ProductRail.jsx).
class ProductRail extends StatelessWidget {
  const ProductRail({super.key, required this.title, required this.products, this.href, this.muted = false});
  final String title;
  final List<Product> products;
  final String? href;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    // A little of the next card shows, so the row reads as swipeable.
    final w = (MediaQuery.of(context).size.width - 16) / 2.25;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionTitle(title, size: 18, onViewAll: href == null || href!.isEmpty ? null : () => AppRouter.open(context, href!)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: w, child: ProductCard(product: products[i])),
            ),
          ),
        ],
      ),
    );
  }
}

/// The deal card in "Today's Commercial Deals" (DealSlider.jsx).
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final save = p.mrp > p.price ? p.mrp - p.price : 0;
    return GestureDetector(
      onTap: () => AppRouter.push(context, ProductScreen(id: p.id, name: p.name)),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DF.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 132,
              width: double.infinity,
              color: DF.stage,
              padding: const EdgeInsets.all(10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The picture starts under the offer ribbon, not behind it.
                  Positioned.fill(top: p.discountPercent > 0 ? 22 : 0, child: NetImage(p.image)),
                  if (p.discountPercent > 0) Positioned(left: -10, top: 0, child: DiscountRibbon(percent: p.discountPercent)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 15, color: DF.star),
                    const SizedBox(width: 3),
                    Text('${(p.rating > 0 ? p.rating : 4.5).toStringAsFixed(1)} (${p.reviewCount})',
                        style: const TextStyle(fontSize: 12, color: DF.ink500)),
                  ]),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 36,
                    child: Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink900, height: 1.3)),
                  ),
                  const SizedBox(height: 6),
                  if (p.price > 0) ...[
                    Row(children: [
                      Text(formatPrice(p.price), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                      const SizedBox(width: 6),
                      if (p.mrp > p.price)
                        Flexible(
                          child: Text(formatPrice(p.mrp),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: DF.ink400, decoration: TextDecoration.lineThrough)),
                        ),
                    ]),
                    SizedBox(
                      height: 18,
                      child: save > 0
                          ? Text('You save ${formatPrice(save)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DF.save))
                          : null,
                    ),
                  ] else
                    const SizedBox(
                        height: 40,
                        child: Text('Price on request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlineButton('View deal',
                        height: 32,
                        radius: 8,
                        fontSize: 13,
                        onPressed: () => AppRouter.push(context, ProductScreen(id: p.id, name: p.name))),
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

/// A small row: 72px thumbnail, name, category, price (HomeColumns.jsx,
/// related lists, wishlist).
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, this.rank, this.trailing});
  final Product product;
  final int? rank;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return InkWell(
      onTap: () => AppRouter.push(context, ProductScreen(id: p.id, name: p.name)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 26,
                child: Text('$rank', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DF.primary300)),
              ),
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: DF.stage, borderRadius: BorderRadius.circular(12)),
              child: NetImage(p.image),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink900, height: 1.3)),
                  if (p.categoryName.isNotEmpty) Text(p.categoryName, style: const TextStyle(fontSize: 12, color: DF.ink400)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(p.price > 0 ? formatPrice(p.price) : 'Price on request',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DF.ink900)),
                    if (p.mrp > p.price) ...[
                      const SizedBox(width: 6),
                      Text(formatPrice(p.mrp),
                          style: const TextStyle(fontSize: 12, color: DF.ink400, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: DF.saveBg, borderRadius: BorderRadius.circular(5)),
                        child: Text('${p.discountPercent}% off',
                            style: const TextStyle(fontSize: 11, color: DF.save, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
