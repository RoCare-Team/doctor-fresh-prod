import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'skeleton.dart';

/// A network image with the site's soft placeholder while it loads and a
/// quiet icon when it cannot be fetched.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.contain, this.width, this.height});

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ImageSkeleton(width: width, height: height);
      },
      errorBuilder: (context, error, stack) => _fallback(),
    );
  }

  Widget _fallback() => SizedBox(
        width: width,
        height: height,
        child: const Center(child: Icon(Icons.water_drop_outlined, color: DF.ink300, size: 28)),
      );
}
