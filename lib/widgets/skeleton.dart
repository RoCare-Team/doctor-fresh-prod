import 'package:flutter/material.dart';

/// Loading placeholders in the shape of what is coming — grey blocks with a
/// light sweeping across them — so a screen never opens on a lone spinner.
/// Written with the SDK alone: one clock per screen, and every block paints
/// its own sliding gradient from it (the white cards around them stay white).

const _base = Color(0xFFE3E9EF);
const _highlight = Color(0xFFF5F8FA);

/// Runs the sweep for every [SkelBox] inside [child].
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ShimmerClock(clock: _c, child: widget.child);
}

class _ShimmerClock extends InheritedWidget {
  const _ShimmerClock({required this.clock, required super.child});
  final Animation<double> clock;

  @override
  bool updateShouldNotify(_ShimmerClock old) => old.clock != clock;
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// One grey block; it shimmers when a [Shimmer] is above it.
class SkelBox extends StatelessWidget {
  const SkelBox({super.key, this.width, this.height = 12, this.radius = 8, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  BoxDecoration _decoration(double? t) => BoxDecoration(
        color: t == null ? _base : null,
        gradient: t == null
            ? null
            : LinearGradient(
                colors: const [_base, _highlight, _base],
                stops: const [0.3, 0.5, 0.7],
                transform: _Slide(t),
              ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      );

  @override
  Widget build(BuildContext context) {
    final clock = context.dependOnInheritedWidgetOfExactType<_ShimmerClock>()?.clock;
    final size = (w: circle ? height : width, h: height);
    final Widget box = clock == null
        ? Container(width: size.w, height: size.h, decoration: _decoration(null))
        : AnimatedBuilder(
            animation: clock,
            builder: (context, _) => Container(width: size.w, height: size.h, decoration: _decoration(clock.value)),
          );
    // A block with its own width keeps it, even in a list that stretches
    // its children across the screen.
    if (size.w == null) return box;
    return Align(alignment: Alignment.centerLeft, widthFactor: 1, heightFactor: 1, child: box);
  }
}

/// A white card holding placeholder lines.
class _SkelCard extends StatelessWidget {
  const _SkelCard({required this.child, this.padding = const EdgeInsets.all(8)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

/// The shape of a [ProductCard]: picture, two lines of name, price, buttons.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SkelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkelBox(height: 120, radius: 12),
          SizedBox(height: 10),
          SkelBox(height: 12),
          SizedBox(height: 6),
          SkelBox(width: 90, height: 12),
          SizedBox(height: 12),
          SkelBox(width: 70, height: 16),
          SizedBox(height: 6),
          SkelBox(width: 100, height: 10),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkelBox(height: 38)),
              SizedBox(width: 6),
              SkelBox(width: 38, height: 38),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 2-column grid of card skeletons (listings, search).
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 6, this.withChips = false});
  final int count;
  final bool withChips;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (withChips) ...[
            const Row(
              children: [
                SkelBox(width: 52, height: 36, radius: 18),
                SizedBox(width: 8),
                SkelBox(width: 140, height: 36, radius: 18),
                SizedBox(width: 8),
                Expanded(child: SkelBox(height: 36, radius: 18)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const Row(
            children: [
              SkelBox(width: 110, height: 14),
              Spacer(),
              SkelBox(width: 90, height: 36, radius: 10),
              SizedBox(width: 8),
              SkelBox(width: 110, height: 36, radius: 10),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 16,
              children: [for (var i = 0; i < count; i++) SizedBox(width: w, child: const ProductCardSkeleton())],
            );
          }),
        ],
      ),
    );
  }
}

/// The Home tab while it loads: banner, category circles, service tiles,
/// a row of products.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cardW = (MediaQuery.of(context).size.width - 16) / 2.25;
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 14),
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkelBox(height: 168, radius: 20)),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SkelCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkelBox(width: 140, height: 16),
                  const SizedBox(height: 14),
                  for (var row = 0; row < 2; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (var i = 0; i < 4; i++)
                            const Column(
                                children: [SkelBox(height: 60, circle: true), SizedBox(height: 8), SkelBox(width: 56, height: 10)]),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkelBox(width: 190, height: 18)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: SkelBox(height: 96, radius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkelBox(height: 96, radius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkelBox(height: 96, radius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkelBox(height: 96, radius: 16)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkelBox(width: 210, height: 18)),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(padding: const EdgeInsets.only(right: 10), child: SizedBox(width: cardW, child: const ProductCardSkeleton())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A product page while it loads: gallery, title, price, buttons, details.
class ProductDetailSkeleton extends StatelessWidget {
  const ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          AspectRatio(aspectRatio: 1, child: SkelBox(radius: 16)),
          SizedBox(height: 14),
          Center(child: SkelBox(width: 60, height: 6)),
          SizedBox(height: 18),
          Row(children: [
            SkelBox(width: 160, height: 26, radius: 13),
            Spacer(),
            SkelBox(width: 70, height: 20),
            SizedBox(width: 10),
            SkelBox(width: 60, height: 20)
          ]),
          SizedBox(height: 16),
          SkelBox(height: 20),
          SizedBox(height: 8),
          SkelBox(width: 220, height: 20),
          SizedBox(height: 14),
          SkelBox(height: 12),
          SizedBox(height: 6),
          SkelBox(width: 260, height: 12),
          SizedBox(height: 16),
          Row(children: [
            SkelBox(width: 54, height: 22),
            SizedBox(width: 10),
            SkelBox(width: 80, height: 14),
            SizedBox(width: 12),
            SkelBox(width: 70, height: 14)
          ]),
          SizedBox(height: 20),
          Row(children: [SkelBox(width: 60, height: 32), SizedBox(width: 12), SkelBox(width: 150, height: 32)]),
          SizedBox(height: 8),
          SkelBox(width: 200, height: 12),
          SizedBox(height: 22),
          Row(children: [
            Expanded(child: SkelBox(height: 48, radius: 12)),
            SizedBox(width: 12),
            Expanded(child: SkelBox(height: 48, radius: 12))
          ]),
          SizedBox(height: 18),
          SkelBox(height: 110, radius: 16),
        ],
      ),
    );
  }
}

/// The general one: a few cards of lines (orders, blog, stores, services…).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 5, this.withImage = true});
  final int count;
  final bool withImage;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SkelCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (withImage) ...[const SkelBox(width: 72, height: 72, radius: 12), const SizedBox(width: 14)],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkelBox(height: 14),
                          SizedBox(height: 8),
                          SkelBox(width: 150, height: 12),
                          SizedBox(height: 14),
                          SkelBox(width: 90, height: 16),
                        ],
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
}

/// The placeholder behind a picture that is still downloading.
class ImageSkeleton extends StatelessWidget {
  const ImageSkeleton({super.key, this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // Inside a column (an article's pictures) there is no height to fill.
        final w = width ?? (box.hasBoundedWidth ? box.maxWidth : 160.0);
        final h = height ?? (box.hasBoundedHeight ? box.maxHeight : 160.0);
        return Shimmer(child: SkelBox(width: w, height: h, radius: 0));
      });
}
