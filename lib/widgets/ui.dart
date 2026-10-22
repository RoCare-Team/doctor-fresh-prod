import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'skeleton.dart';

/// Small building blocks shared by every screen, styled after the website's
/// Tailwind classes.

/// A filled primary button (48px, radius 12) — "Buy Now", "Send OTP", …
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 48,
    this.color = DF.primary600,
    this.radius = 12,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final Color color;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// An outlined button — "Add to Cart", "Call a water expert", …
class OutlineButton extends StatelessWidget {
  const OutlineButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.height = 48,
    this.color = DF.primary600,
    this.borderColor,
    this.radius = 12,
    this.fontSize = 15,
    this.fill,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color color;
  final Color? borderColor;
  final double radius;
  final double fontSize;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: fill ?? Colors.white,
          side: BorderSide(color: borderColor ?? color, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// "Water Purifier Services | At your doorstep" — the site's section heading
/// with an optional "View all →" on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.highlight, this.suffix, this.onViewAll, this.size = 22, this.eyebrow});

  final String title;
  final String? highlight;
  final String? suffix;
  final String? eyebrow;
  final VoidCallback? onViewAll;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[Text(eyebrow!.toUpperCase(), style: DF.eyebrow), const SizedBox(height: 4)],
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: DF.ink900, letterSpacing: -0.3, height: 1.2),
                  children: [
                    TextSpan(text: title),
                    if (highlight != null) TextSpan(text: ' $highlight', style: const TextStyle(color: DF.primary600)),
                    if (suffix != null)
                      TextSpan(
                        text: '  |  $suffix',
                        style: TextStyle(fontSize: size * 0.62, fontWeight: FontWeight.w500, color: DF.ink400),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onViewAll != null)
          InkWell(
            onTap: onViewAll,
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
    );
  }
}

/// The price line every card uses: price, struck MRP, "{n}% off".
class PriceLine extends StatelessWidget {
  const PriceLine({super.key, required this.price, required this.mrp, this.discount = 0, this.size = 15, this.unit = ''});

  final num price;
  final num mrp;
  final int discount;
  final double size;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (price <= 0) {
      return Text('Price on request', style: TextStyle(fontSize: size - 1, fontWeight: FontWeight.w600, color: DF.ink900));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatPrice(price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: DF.ink900)),
        if (mrp > price)
          Row(
            children: [
              Text(
                formatPrice(mrp),
                style: const TextStyle(fontSize: 12, color: DF.ink400, decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(width: 6),
              if (discount > 0)
                Text('$discount% off', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DF.primary700)),
            ],
          ),
      ],
    );
  }
}

/// "4.3★" on a green chip.
class RatingChip extends StatelessWidget {
  const RatingChip(this.rating, {super.key, this.size = 11.5});
  final num rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rating.toStringAsFixed(1), style: TextStyle(color: DF.primary700, fontSize: size, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          Icon(Icons.star_rounded, color: DF.primary700, size: size + 1),
        ],
      ),
    );
  }
}

/// − qty + (the cart and the product page).
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99, this.height = 36});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, int next) => SizedBox(
          width: height,
          height: height,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: enabled ? () => onChanged(next) : null,
            icon: Icon(icon, size: 18),
            color: DF.ink900,
            disabledColor: DF.ink300,
          ),
        );
    return Container(
      height: height,
      decoration: BoxDecoration(border: Border.all(color: DF.lineStrong), borderRadius: BorderRadius.circular(height > 40 ? 12 : 10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, value > min, value - 1),
          SizedBox(
            width: 36,
            child: Text('$value',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink900, fontSize: 15)),
          ),
          btn(Icons.add, value < max, value + 1),
        ],
      ),
    );
  }
}

/// A rounded white card with the site's line border (`.df-card`).
class DFCard extends StatelessWidget {
  const DFCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.color = Colors.white,
      this.radius = 16,
      this.borderColor = DF.line,
      this.margin});

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color color;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// A form field with its label above, as the site's forms lay them out.
class DFField extends StatelessWidget {
  const DFField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.keyboard,
    this.hint,
    this.maxLength,
    this.digitsOnly = false,
    this.maxLines = 1,
    this.prefix,
    this.error,
    this.onChanged,
    this.readOnly = false,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboard;
  final String? hint;
  final int? maxLength;
  final bool digitsOnly;
  final int maxLines;
  final String? prefix;
  final String? error;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700),
            children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: DF.danger))],
          )),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            maxLines: maxLines,
            readOnly: readOnly,
            obscureText: obscure,
            onChanged: onChanged,
            inputFormatters: [
              if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ],
            style: const TextStyle(fontSize: 15, color: DF.ink900),
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
              fillColor: readOnly ? DF.surfaceMuted : Colors.white,
              prefixIcon: prefix == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Text(prefix!, style: const TextStyle(fontSize: 15, color: DF.ink500)),
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dropdown with the same look as [DFField].
class DFDropdown extends StatelessWidget {
  const DFDropdown(
      {super.key,
      required this.label,
      required this.items,
      required this.value,
      required this.onChanged,
      this.required = false,
      this.hint = 'Select'});

  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700),
            children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: DF.danger))],
          )),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : null,
            isExpanded: true,
            hint: Text(hint, style: const TextStyle(color: DF.ink300)),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15, color: DF.ink900),
          ),
        ],
      ),
    );
  }
}

/// A full-screen loading / error state, with a retry. While loading it
/// shows [skeleton] — the shape of the screen to come — or rows of cards.
class LoadState extends StatelessWidget {
  const LoadState({super.key, this.error, this.onRetry, this.skeleton});
  final String? error;
  final VoidCallback? onRetry;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    if (error == null) return skeleton ?? const ListSkeleton();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: DF.ink300),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center, style: DF.muted),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlineButton('Try again', onPressed: onRetry, height: 42),
            ],
          ],
        ),
      ),
    );
  }
}

/// A screen's data, loaded once with a retry: `Loader(load: () => api..., builder: ...)`.
class Loader extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.skeleton});

  final Future<ApiResult> Function() load;
  final Widget? skeleton;
  final Widget Function(BuildContext context, Map<String, dynamic> data, Future<void> Function() reload) builder;

  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final res = await widget.load();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res.ok) {
        data = res.data is List ? {'items': res.data} : res.map;
      } else {
        error = res.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return LoadState(error: loading ? null : error, onRetry: _load, skeleton: widget.skeleton);
    return widget.builder(context, data!, _load);
  }
}

/// A bottom sheet with the site's rounded top and a title row.
Future<T?> showDFSheet<T>(BuildContext context, {required String title, String? subtitle, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: DF.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: DF.h2),
                        if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: DF.muted)],
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: DF.ink500)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: builder(ctx),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A green "done" message used after forms are sent.
class SuccessNote extends StatelessWidget {
  const SuccessNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: DF.saveBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: DF.save, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: DF.save, fontSize: 14, height: 1.45))),
        ],
      ),
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(color: DF.danger, fontSize: 13.5)),
    );
  }
}

/// A pill chip, selectable.
class DFChip extends StatelessWidget {
  const DFChip(this.label, {super.key, this.selected = false, this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DF.primary600 : Colors.white,
          border: Border.all(color: selected ? DF.primary600 : DF.lineStrong),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: selected ? Colors.white : DF.ink500), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: selected ? Colors.white : DF.ink700)),
          ],
        ),
      ),
    );
  }
}
