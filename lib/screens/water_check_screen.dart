import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/purifier.dart';
import '../core/theme.dart';
import '../router.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

/// Water check: the customer gives the TDS of their water and where it comes
/// from, and the app says which purification it needs — the questions our
/// technicians ask before recommending a purifier.
class WaterCheckScreen extends StatefulWidget {
  const WaterCheckScreen({super.key, this.initialTds});
  final int? initialTds;

  @override
  State<WaterCheckScreen> createState() => _WaterCheckScreenState();
}

class _Verdict {
  const _Verdict(this.level, this.color, this.tech, this.text);
  final String level;
  final Color color;
  final String tech;
  final String text;
}

class _WaterCheckScreenState extends State<WaterCheckScreen> {
  static const sources = ['Municipal supply', 'Borewell', 'Tanker', 'Mixed'];

  late double tds = (widget.initialTds ?? 350).clamp(0, 2000).toDouble();
  String source = 'Municipal supply';

  // BIS IS 10500: up to 500 mg/l acceptable, 2000 the limit without another source.
  _Verdict get verdict {
    final t = tds.round();
    if (t < 150) {
      return const _Verdict('Low TDS', DF.primary600, 'UV + UF',
          'Your water is already low in dissolved salts. UV + UF removes germs and dirt while keeping the minerals; RO would strip them out.');
    }
    if (t < 300) {
      return const _Verdict('Good', DF.success, 'UV + UF, or RO with a mineral cartridge',
          'Safe on salts. Germs are the main concern, so UV is a must; choose RO with a TDS controller if the taste is off.');
    }
    if (t <= 500) {
      return const _Verdict('Acceptable', DF.warning, 'RO + UV',
          'Within the BIS limit, but hard enough to taste and scale. RO brings the salts down and UV keeps it germ-free.');
    }
    if (t <= 1200) {
      return const _Verdict('High', DF.danger, 'RO + UV with TDS controller',
          'Above the BIS acceptable limit of 500 ppm. RO is needed, with a TDS controller so the water keeps its healthy minerals.');
    }
    return const _Verdict('Very high', DF.danger, 'RO + UV, high-recovery membrane',
        'Far above the safe limit. Use a heavy-duty RO membrane and get the water tested by a technician before choosing a purifier.');
  }

  bool get _groundWater => source == 'Borewell' || source == 'Tanker' || source == 'Mixed';

  @override
  Widget build(BuildContext context) {
    final v = verdict;
    final mine = PurifierStore.instance.current.value;

    return DFScaffold(
      title: 'Water check',
      showCart: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('TDS of your water', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink700)),
                const SizedBox(height: 4),
                const Text('Total dissolved solids, in ppm. Read it with a TDS meter, or ask our technician at the next visit.',
                    style: TextStyle(fontSize: 12.5, color: DF.ink400, height: 1.45)),
                const SizedBox(height: 14),
                Center(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${tds.round()}', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: v.color)),
                    const TextSpan(text: '  ppm', style: TextStyle(fontSize: 15, color: DF.ink400)),
                  ])),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: v.color,
                    thumbColor: v.color,
                    inactiveTrackColor: DF.line,
                    overlayColor: v.color.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: tds,
                    max: 2000,
                    divisions: 400,
                    onChanged: (x) {
                      // A tick each time the reading crosses into another band.
                      if (_band(x) != _band(tds)) HapticFeedback.selectionClick();
                      setState(() => tds = x);
                    },
                  ),
                ),
                // 500 sits a quarter of the way along the 0–2000 scale.
                const SizedBox(
                  height: 16,
                  child: Stack(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: Text('0', style: TextStyle(fontSize: 11.5, color: DF.ink300))),
                      Align(alignment: Alignment(-0.5, 0), child: Text('500 · BIS limit', style: TextStyle(fontSize: 11.5, color: DF.ink300))),
                      Align(alignment: Alignment.centerRight, child: Text('2000', style: TextStyle(fontSize: 11.5, color: DF.ink300))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Where does it come from?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final s in sources) DFChip(s, selected: s == source, onTap: () => setState(() => source = s))],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: v.color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop_rounded, color: v.color),
                    const SizedBox(width: 8),
                    Text(v.level, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: v.color)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Recommended purification', style: TextStyle(fontSize: 12, color: DF.ink400)),
                Text(v.tech, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                const SizedBox(height: 8),
                Text(v.text, style: const TextStyle(fontSize: 13.5, color: DF.ink700, height: 1.5)),
                if (_groundWater) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Ground and tanker water often carry bacteria and hardness that change with the season — keep UV in the purifier and check the TDS every few months.',
                    style: TextStyle(fontSize: 13, color: DF.ink500, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Shop purifiers', icon: Icons.storefront_outlined, onPressed: () => AppRouter.open(context, '/category/water-purifier')),
          const SizedBox(height: 10),
          if (mine != null)
            OutlineButton('Save to my purifier', icon: Icons.bookmark_add_outlined, onPressed: () async {
              mine.tds = tds.round();
              await PurifierStore.instance.save(mine);
              if (context.mounted) toast(context, 'Saved to your purifier.');
            })
          else
            OutlineButton('Ask an expert', icon: Icons.call_outlined, onPressed: () => Native.call()),
        ],
      ),
    );
  }

  static int _band(double t) => t < 150 ? 0 : t < 300 ? 1 : t <= 500 ? 2 : t <= 1200 ? 3 : 4;
}
