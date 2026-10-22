import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/html_view.dart';
import '../widgets/net_image.dart';
import '../widgets/product_card.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';
import '../widgets/skeleton.dart';

/// A category or subcategory listing (app/(shop)/category/[category]/page.jsx,
/// .../[subcategory]/page.jsx and app/(shop)/spare-parts/page.jsx), from
/// GET /api/mobile/category?path=…, with CategoryProducts.jsx's sort, filters
/// and paging.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.path, this.title});
  final String path;
  final String? title;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool introOpen = false;

  bool get spareParts => widget.path.replaceAll('/', '') == 'spare-parts';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    final res = await Api.instance.get('/api/mobile/category', query: {'path': widget.path});
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        data = res.map;
      } else {
        error = res.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (data == null)
      return DFScaffold(
          title: widget.title ?? '', body: LoadState(error: error, onRetry: _load, skeleton: const ProductGridSkeleton(withChips: true)));

    final category = (data!['category'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final sub = (data!['subcategory'] as Map?)?.cast<String, dynamic>();
    final page = sub ?? category;
    final products = mapsOf(data!['products']).map(Product.fromJson).toList();
    final subcategories = mapsOf(category['subcategories']);
    final heading = spareParts
        ? (widget.title ?? 'Water purifier spare parts')
        : (str(page['heading']).isNotEmpty ? str(page['heading']) : str(page['name']));
    final intro = spareParts && str(page['intro']).isEmpty
        ? 'Genuine filters, RO membranes, cartridges, pumps and UV lamps for every Doctor Fresh water purifier model.'
        : plainText(str(page['intro']));
    final faqs = mapsOf(page['faqs']);

    // App layout: the name is in the app bar, the ranges sit in a strip
    // under it, the products come first and the category's write-up moves
    // to an "About" card below them.
    return DFScaffold(
      title: spareParts ? 'Spare parts' : str((sub ?? category)['name']),
      showSearch: true,
      body: RefreshIndicator(
        color: DF.primary600,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (!spareParts && subcategories.isNotEmpty)
              Container(
                color: Colors.white,
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  itemCount: subcategories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return DFChip(
                        'All',
                        selected: sub == null,
                        onTap: sub == null ? null : () => AppRouter.push(context, CategoryScreen(path: str(category['slug']))),
                      );
                    }
                    final s = subcategories[i - 1];
                    final active = sub != null && str(s['slug']) == str(sub['slug']);
                    return DFChip(
                      str(s['name']),
                      selected: active,
                      onTap: active ? null : () => AppRouter.push(context, CategoryScreen(path: '${category['slug']}/${s['slug']}')),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _CategoryProducts(
                products: products,
                subcategories: spareParts ? const [] : subcategories,
                categorySlug: str(category['slug']),
                activeSlug: sub == null ? null : str(sub['slug']),
              ),
            ),
            if (intro.isNotEmpty)
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(intro,
                        maxLines: introOpen ? null : 4,
                        overflow: introOpen ? null : TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: DF.ink500, height: 1.55)),
                    GestureDetector(
                      onTap: () => setState(() => introOpen = !introOpen),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(introOpen ? 'Read less' : 'Read more',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: DF.primary700)),
                      ),
                    ),
                  ],
                ),
              ),
            if (faqs.isNotEmpty)
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Frequently asked questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                    const SizedBox(height: 4),
                    _FaqAccordion(items: faqs),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------------------------- results, sort, filter */

const _sorts = [
  ('featured', 'Featured'),
  ('price-asc', 'Price: low to high'),
  ('price-desc', 'Price: high to low'),
  ('rating', 'Customer rating'),
  ('name', 'Name: A to Z'),
];

const _pageSize = 12;

/// CategoryProducts.jsx — the results bar, the mobile filters sheet, the
/// grid in pages of twelve and the empty states.
class _CategoryProducts extends StatefulWidget {
  const _CategoryProducts({required this.products, required this.subcategories, required this.categorySlug, this.activeSlug});
  final List<Product> products;
  final List<Map<String, dynamic>> subcategories;
  final String categorySlug;
  final String? activeSlug;

  @override
  State<_CategoryProducts> createState() => _CategoryProductsState();
}

class _CategoryProductsState extends State<_CategoryProducts> {
  String sort = 'featured';
  int? maxPrice;
  bool inStockOnly = false;
  int visible = _pageSize;

  List<int> get priceBuckets {
    final priced = widget.products.where((p) => p.price > 0).map((p) => p.price).toList();
    if (priced.isEmpty) return const [];
    final top = priced.reduce((a, b) => a > b ? a : b);
    return [5000, 10000, 20000, 50000, 100000].where((b) => b < top).take(4).toList();
  }

  List<Product> get filtered {
    var list = [...widget.products];
    if (maxPrice != null) list = list.where((p) => p.price > 0 && p.price <= maxPrice!).toList();
    if (inStockOnly) list = list.where((p) => p.inStock).toList();
    num orInf(num v) => v > 0 ? v : double.infinity;
    switch (sort) {
      case 'price-asc':
        list.sort((a, b) => orInf(a.price).compareTo(orInf(b.price)));
      case 'price-desc':
        list.sort((a, b) => b.price.compareTo(a.price));
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 'name':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  bool get hasFilters => maxPrice != null || inStockOnly;

  void _clear() => setState(() {
        maxPrice = null;
        inStockOnly = false;
        visible = _pageSize;
      });

  String get _clearedMessage {
    final reasons = [
      if (maxPrice != null) 'nothing here is under ${formatPrice(maxPrice)}',
      if (inStockOnly) 'nothing is in stock right now',
    ].join(', and ');
    return reasons.isEmpty
        ? 'Try widening your filters.'
        : '${reasons[0].toUpperCase()}${reasons.substring(1)}. Try widening your filters.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return _EmptyState(
        title: 'Nothing listed here yet',
        message: 'Products in this category are available on request — tell us what you need and we will quote it.',
        actions: [
          PrimaryButton('Request a quotation', onPressed: () => AppRouter.open(context, '/contact')),
          OutlineButton('Call ${Config.phone}', onPressed: () => Native.call()),
        ],
      );
    }

    final list = filtered;
    final shown = list.take(visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // results bar
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DF.line))),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text.rich(TextSpan(
                style: const TextStyle(fontSize: 14, color: DF.ink500),
                children: [
                  const TextSpan(text: '1-'),
                  TextSpan(text: '${shown.length}', style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink900)),
                  const TextSpan(text: ' of '),
                  TextSpan(text: '${list.length}', style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink900)),
                  const TextSpan(text: ' results'),
                ],
              )),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _openFilters,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: hasFilters ? DF.primary50 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: hasFilters ? DF.primary500 : DF.lineStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 15, color: hasFilters ? DF.primary800 : DF.ink700),
                          const SizedBox(width: 8),
                          Text('Filters',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: hasFilters ? DF.primary800 : DF.ink700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DF.lineStrong),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sort,
                        isDense: true,
                        icon: const Icon(Icons.expand_more, size: 18, color: DF.ink500),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DF.ink900),
                        items: [for (final (v, l) in _sorts) DropdownMenuItem(value: v, child: Text(l))],
                        onChanged: (v) => setState(() => sort = v ?? 'featured'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (list.isNotEmpty)
          ProductGrid(products: shown)
        else
          _EmptyState(
            title: 'No products match these filters',
            message: _clearedMessage,
            actions: [PrimaryButton('Clear filters', onPressed: _clear)],
          ),
        if (visible < list.length) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlineButton('Load more products', onPressed: () => setState(() => visible += _pageSize)),
          ),
        ],
      ],
    );
  }

  void _openFilters() {
    showDFSheet(
      context,
      title: 'Filters',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void update(VoidCallback fn) {
          setState(fn);
          setSheet(() {});
        }

        Widget heading(String t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t.toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: DF.ink400)),
            );

        Widget row({required bool active, required Widget child, required VoidCallback onTap}) => InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(color: active ? DF.primary50 : null, borderRadius: BorderRadius.circular(6)),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? DF.primary800 : DF.ink500,
                  ),
                  child: child,
                ),
              ),
            );

        final sections = <Widget>[
          if (widget.subcategories.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Category'),
                for (final s in widget.subcategories)
                  row(
                    active: str(s['slug']) == widget.activeSlug,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (str(s['slug']) == widget.activeSlug) return;
                      AppRouter.push(context, CategoryScreen(path: '${widget.categorySlug}/${s['slug']}'));
                    },
                    child: Text(str(s['name'])),
                  ),
              ],
            ),
          if (priceBuckets.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Price'),
                for (final b in priceBuckets)
                  row(
                    active: maxPrice == b,
                    onTap: () => update(() {
                      maxPrice = b;
                      visible = _pageSize;
                    }),
                    child: Row(children: [
                      _Tick(round: true, on: maxPrice == b),
                      const SizedBox(width: 10),
                      Text('Under ${formatPrice(b)}'),
                    ]),
                  ),
              ],
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading('Availability'),
              row(
                active: inStockOnly,
                onTap: () => update(() {
                  inStockOnly = !inStockOnly;
                  visible = _pageSize;
                }),
                child: Row(children: [
                  _Tick(round: false, on: inStockOnly),
                  const SizedBox(width: 10),
                  const Text('In stock only'),
                ]),
              ),
            ],
          ),
          if (hasFilters)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => update(() {
                  maxPrice = null;
                  inStockOnly = false;
                  visible = _pageSize;
                }),
                child: const Text('Clear filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DF.primary600)),
              ),
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in sections.indexed) ...[
              if (i > 0) const Divider(),
              Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: s),
            ],
            const SizedBox(height: 4),
            PrimaryButton('Show ${filtered.length} products', onPressed: () => Navigator.pop(ctx)),
          ],
        );
      }),
    );
  }
}

/// A radio dot or a checkbox tick, in the site's primary colour.
class _Tick extends StatelessWidget {
  const _Tick({required this.round, required this.on});
  final bool round;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: on && !round ? DF.primary500 : Colors.white,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(3),
        border: Border.all(color: on ? DF.primary500 : DF.ink300, width: on && round ? 4.5 : 1.5),
      ),
      child: on && !round ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
    );
  }
}

/* ---------------------------------------------------------- all categories */

/// app/(shop)/all-category/page.jsx — every category with its subcategories,
/// from the menu data (/api/mobile/menu).
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  bool loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMenu());
  }

  Future<void> _ensureMenu() async {
    final state = AppScope.read(context);
    if (state.categories.isNotEmpty) return;
    setState(() => loading = true);
    await state.loadMenu();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = AppScope.of(context).categories;
    if (categories.isEmpty) {
      return DFScaffold(
        title: 'All products',
        body: LoadState(error: loading ? null : 'Could not load the categories.', onRetry: _ensureMenu),
      );
    }

    return DFScaffold(
      title: 'All products',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final c in categories) _categoryCard(c),
        ],
      ),
    );
  }

  Widget _categoryCard(Map<String, dynamic> c) {
    final subs = mapsOf(c['subcategories']);
    final count = toInt(c['productCount']);
    final image = str(c['image']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => AppRouter.open(context, str(c['href'])),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  if (image.isNotEmpty) ...[
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: DF.stage, borderRadius: BorderRadius.circular(10)),
                      child: NetImage(Config.url(image)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(c['name']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                        if (count > 0) ...[
                          const SizedBox(height: 2),
                          Text('$count products', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: DF.ink300),
                ],
              ),
            ),
          ),
          if (subs.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subs) DFChip(str(s['name']), onTap: () => AppRouter.open(context, str(s['href']))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ search */

/// app/(shop)/search/page.jsx — GET /api/mobile/products?q=…
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.query = ''});
  final String query;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final input = TextEditingController(text: widget.query.trim());
  String query = '';
  List<Product>? results;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.query.trim().isNotEmpty) _search(widget.query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.read(context).categories.isEmpty) AppScope.read(context).loadMenu();
    });
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    setState(() {
      query = q;
      results = null;
      error = null;
      loading = q.isNotEmpty;
    });
    if (q.isEmpty) return;
    final res = await Api.instance.get('/api/mobile/products', query: {'q': q});
    if (!mounted || q != query) return;
    setState(() {
      loading = false;
      if (res.ok) {
        results = mapsOf(res.map['products']).map(Product.fromJson).toList();
      } else {
        error = res.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Search',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: TextField(
              controller: input,
              autofocus: widget.query.trim().isEmpty,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: const TextStyle(fontSize: 15, color: DF.ink900),
              decoration: InputDecoration(
                hintText: 'Search water purifiers, RO plants, spare parts…',
                prefixIcon: const Icon(Icons.search, color: DF.ink400),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: DF.primary600),
                  onPressed: () => _search(input.text),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: _results(),
            ),
          ),
        ],
      ),
    );
  }

  static const _popular = ['RO water purifier', 'UV purifier', 'Water softener', 'RO membrane', 'Alkaline', 'Commercial RO plant'];

  List<Widget> _results() {
    if (query.isEmpty) {
      final categories = AppScope.of(context).categories;
      Widget heading(String t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
          );
      return [
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Popular searches'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final term in _popular)
                    DFChip(term, icon: Icons.trending_up, onTap: () {
                      input.text = term;
                      _search(term);
                    }),
                ],
              ),
            ],
          ),
        ),
        if (categories.isNotEmpty)
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('Browse categories'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in categories) DFChip(str(c['name']), onTap: () => AppRouter.open(context, str(c['href']))),
                  ],
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Search by product name, technology or category.', style: TextStyle(fontSize: 13, color: DF.ink400)),
        ),
      ];
    }
    if (loading || error != null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: LoadState(error: loading ? null : error, onRetry: () => _search(query), skeleton: const ProductGridSkeleton(count: 4)),
        ),
      ];
    }
    final list = results ?? const <Product>[];
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _EmptyState(
            title: 'No products found for “$query”',
            message: "Try a shorter search term — a model name or just 'RO' often works better than a full sentence.",
            actions: [PrimaryButton('Browse all categories', onPressed: () => AppRouter.push(context, const AllCategoriesScreen()))],
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Text.rich(TextSpan(
          style: const TextStyle(fontSize: 13, color: DF.ink400),
          children: [
            TextSpan(text: '${list.length}', style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink700)),
            TextSpan(text: ' ${list.length == 1 ? 'result' : 'results'} for “$query”'),
          ],
        )),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ProductGrid(products: list)),
    ];
  }
}

/* ----------------------------------------------------------------- shared */

/// A white block on the grey canvas, 8px below the one before it.
class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: child,
      );
}

/// EmptyState.jsx — an empty carton, a line saying why, and a way out.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, this.message, this.actions = const []});
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined, size: 40, color: DF.ink300),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: DF.ink400, height: 1.5)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Accordion.jsx inside FaqSection.jsx — the first answer open.
class _FaqAccordion extends StatefulWidget {
  const _FaqAccordion({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<_FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<_FaqAccordion> {
  int open = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in widget.items.indexed) ...[
          if (i > 0) const Divider(),
          InkWell(
            onTap: () => setState(() => open = open == i ? -1 : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        Text(str(item['question']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900)),
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
              padding: const EdgeInsets.only(bottom: 14),
              child: str(item['answerHtml']).isNotEmpty
                  ? HtmlView(str(item['answerHtml']), onLink: (h) => AppRouter.open(context, h))
                  : Text(str(item['answer']), style: DF.body),
            ),
        ],
      ],
    );
  }
}
