import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/net_image.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';
import 'catalog_screens.dart';

/// The Categories tab: the site's category tree (/api/mobile/menu) the way
/// shopping apps show it — categories down the left, the chosen one's
/// ranges on the right.
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  int selected = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
  }

  Future<void> _ensure() async {
    final state = AppScope.read(context);
    if (state.categories.isNotEmpty) return;
    setState(() => loading = true);
    await state.loadMenu();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = AppScope.of(context).categories;

    return DFScaffold(
      title: 'Categories',
      showSearch: true,
      backgroundColor: Colors.white,
      body: categories.isEmpty
          ? LoadState(error: loading ? null : 'Could not load the categories.', onRetry: _ensure)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // left rail
                Container(
                  width: 96,
                  color: DF.canvas,
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (_, i) => _railItem(categories[i], i == selected, () => setState(() => selected = i)),
                  ),
                ),
                // right panel
                Expanded(child: _panel(categories[selected.clamp(0, categories.length - 1)])),
              ],
            ),
    );
  }

  Widget _railItem(Map<String, dynamic> c, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          border: Border(left: BorderSide(color: active ? DF.primary600 : Colors.transparent, width: 3)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: active ? DF.primary50 : Colors.white, shape: BoxShape.circle),
              child: ClipOval(child: NetImage('${c['image'] ?? ''}')),
            ),
            const SizedBox(height: 6),
            Text(
              '${c['name']}',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? DF.primary700 : DF.ink500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(Map<String, dynamic> c) {
    final subs = mapsOf(c['subcategories']);
    final slug = '${c['slug']}';
    return ListView(
      key: PageStorageKey(slug),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      children: [
        // the whole category
        InkWell(
          onTap: () => AppRouter.push(context, CategoryScreen(path: slug)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [DF.primary50, DF.primary100]),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: NetImage('${c['image'] ?? ''}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                      const SizedBox(height: 2),
                      Text('${c['productCount'] ?? 0} products', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                      const SizedBox(height: 6),
                      const Text('View all →', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DF.primary700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Shop by range', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DF.ink900)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in subs)
                  SizedBox(
                    width: w,
                    child: Material(
                      color: DF.canvas,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => AppRouter.push(context, CategoryScreen(path: '$slug/${s['slug']}')),
                        child: Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${s['name']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DF.ink700, height: 1.25)),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: DF.ink300),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ],
    );
  }
}
