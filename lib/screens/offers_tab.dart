import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/product_card.dart';
import '../widgets/shell.dart';
import '../widgets/skeleton.dart';
import '../widgets/ui.dart';

/// The Offers page (Home → deals → View all): every product on sale right now, the biggest discount
/// first, narrowed by category with the chips at the top
/// (GET /api/mobile/products, the whole catalogue as cards).
class OffersTab extends StatefulWidget {
  const OffersTab({super.key});

  @override
  State<OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<OffersTab> {
  List<Product>? offers;
  String? error;
  String category = '';
  bool lowestPrice = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    final res = await Api.instance.get('/api/mobile/products');
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        offers = mapsOf(res.map['products']).map(Product.fromJson).where((p) => p.discountPercent > 0 && p.purchasable).toList()
          ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      } else {
        error = res.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Offers',
      showSearch: true,
      body: offers == null
          ? LoadState(error: error, onRetry: _load, skeleton: const ProductGridSkeleton(withChips: true))
          : RefreshIndicator(color: DF.primary600, onRefresh: _load, child: _body(offers!)),
    );
  }

  Widget _body(List<Product> all) {
    final categories = <String>{for (final p in all) p.categoryName}.where((c) => c.isNotEmpty).toList()..sort();
    final shown = all.where((p) => category.isEmpty || p.categoryName == category).toList();
    if (lowestPrice) shown.sort((a, b) => a.price.compareTo(b.price));
    final best = all.fold<int>(0, (m, p) => p.discountPercent > m ? p.discountPercent : m);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // headline
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF00608F), Color(0xFF0095DC)]),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Up to $best% off', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('${all.length} products on offer · free installation',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xD9FFFFFF))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // category chips
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = i == 0 ? '' : categories[i - 1];
              return DFChip(i == 0 ? 'All offers' : c, selected: category == c, onTap: () => setState(() => category = c));
            },
          ),
        ),

        // count and sort
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
          child: Row(
            children: [
              Text('${shown.length} offers', style: const TextStyle(fontSize: 13, color: DF.ink400)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => lowestPrice = !lowestPrice),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text(lowestPrice ? 'Lowest price' : 'Biggest discount'),
                style: TextButton.styleFrom(foregroundColor: DF.primary700, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('No offers in this category right now.', textAlign: TextAlign.center, style: DF.muted),
          )
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ProductGrid(products: shown)),
      ],
    );
  }
}
