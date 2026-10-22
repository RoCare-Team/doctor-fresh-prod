import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import 'net_image.dart';

/// Renders the rich text the site stores (product descriptions, blog posts,
/// policies) without a package: a small tag reader that understands the tags
/// the admin editor produces — headings, paragraphs, line breaks, bold and
/// italic, links, lists, images and tables.
class HtmlView extends StatelessWidget {
  const HtmlView(this.html, {super.key, this.onLink, this.fontSize = 15});

  final String html;
  final void Function(String href)? onLink;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final nodes = _parse(html);
    final blocks = _Builder(context, onLink, fontSize).build(nodes);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks);
  }
}

/* ------------------------------------------------------------------ parser */

class _Node {
  _Node(this.tag, [this.attrs = const {}]);
  final String tag; // '#text' for text
  final Map<String, String> attrs;
  final List<_Node> children = [];
  String text = '';
}

const _voidTags = {'br', 'img', 'hr', 'meta', 'input', 'source', 'col', 'wbr'};

_Node _parse(String html) {
  final root = _Node('root');
  final stack = <_Node>[root];
  final tagRe = RegExp(r'<(/?)([a-zA-Z0-9]+)([^>]*)>|<!--[\s\S]*?-->|([^<]+)', multiLine: true);
  final cleaned = html.replaceAll(RegExp(r'<(script|style)[\s\S]*?</\1>', caseSensitive: false), '');

  for (final m in tagRe.allMatches(cleaned)) {
    final text = m.group(4);
    if (text != null) {
      final t = _Node('#text')..text = _decode(text);
      stack.last.children.add(t);
      continue;
    }
    final name = (m.group(2) ?? '').toLowerCase();
    if (name.isEmpty) continue; // a comment
    if (m.group(1) == '/') {
      final i = stack.lastIndexWhere((n) => n.tag == name);
      if (i > 0) stack.removeRange(i, stack.length);
      continue;
    }
    final node = _Node(name, _attrs(m.group(3) ?? ''));
    stack.last.children.add(node);
    if (!_voidTags.contains(name) && !(m.group(3) ?? '').trim().endsWith('/')) stack.add(node);
  }
  return root;
}

Map<String, String> _attrs(String s) {
  final out = <String, String>{};
  for (final m in RegExp(r'''([a-zA-Z-]+)\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))''').allMatches(s)) {
    out[m.group(1)!.toLowerCase()] = m.group(3) ?? m.group(4) ?? m.group(5) ?? '';
  }
  return out;
}

String _decode(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&rsquo;', '’')
    .replaceAll('&lsquo;', '‘')
    .replaceAll('&ldquo;', '“')
    .replaceAll('&rdquo;', '”')
    .replaceAll('&ndash;', '–')
    .replaceAll('&mdash;', '—')
    .replaceAll('&hellip;', '…')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#8377;', '₹')
    .replaceAll('&plusmn;', '±')
    .replaceAll('&deg;', '°')
    .replaceAll('&times;', '×')
    .replaceAll('&rupee;', '₹');

/* ----------------------------------------------------------------- builder */

const _blockTags = {
  'p',
  'div',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'table',
  'blockquote',
  'section',
  'article',
  'figure',
  'hr',
  'img',
  'iframe',
  'header',
  'footer',
  'tbody',
  'thead',
  'tr',
};

class _Builder {
  _Builder(this.context, this.onLink, this.fontSize);
  final BuildContext context;
  final void Function(String href)? onLink;
  final double fontSize;

  TextStyle get _base => TextStyle(fontSize: fontSize, height: 1.65, color: DF.ink700);

  List<Widget> build(_Node node) {
    final out = <Widget>[];
    final inline = <_Node>[];

    void flush() {
      if (inline.isEmpty) return;
      final span = TextSpan(children: inline.map((n) => _span(n, _base)).toList());
      if (span.toPlainText().trim().isNotEmpty) {
        out.add(Padding(padding: const EdgeInsets.only(bottom: 12), child: Text.rich(span)));
      }
      inline.clear();
    }

    for (final child in node.children) {
      if (child.tag == '#text' || !_blockTags.contains(child.tag)) {
        inline.add(child);
        continue;
      }
      flush();
      final w = _block(child);
      if (w != null) out.add(w);
    }
    flush();
    return out;
  }

  Widget? _block(_Node n) {
    switch (n.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final size = {'h1': 22.0, 'h2': 20.0, 'h3': 18.0, 'h4': 16.5}[n.tag] ?? 15.5;
        final style = TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: DF.ink900, height: 1.3);
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text.rich(TextSpan(children: n.children.map((c) => _span(c, style)).toList())),
        );
      case 'ul':
      case 'ol':
        final items = n.children.where((c) => c.tag == 'li').toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(n.tag == 'ol' ? '${i + 1}.' : '•',
                            style: _base.copyWith(color: DF.primary600, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _trimBottom(build(items[i])),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'li':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: build(n));
      case 'hr':
        return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider());
      case 'img':
        final src = Config.url(n.attrs['src']);
        if (src.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: NetImage(src, fit: BoxFit.contain)),
        );
      case 'iframe':
        final src = n.attrs['src'] ?? '';
        if (src.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            onPressed: () => onLink?.call(src.startsWith('//') ? 'https:$src' : src),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch video'),
          ),
        );
      case 'table':
      case 'tbody':
      case 'thead':
        return _table(n);
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: DF.primary300, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _trimBottom(build(n))),
        );
      default:
        final children = build(n);
        if (children.isEmpty) return null;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
  }

  List<Widget> _trimBottom(List<Widget> list) =>
      list.map((w) => w is Padding && w.padding == const EdgeInsets.only(bottom: 12) ? w.child ?? w : w).toList();

  Widget _table(_Node n) {
    final rows = <_Node>[];
    void collect(_Node node) {
      for (final c in node.children) {
        if (c.tag == 'tr') {
          rows.add(c);
        } else if (c.tag != '#text') {
          collect(c);
        }
      }
    }

    collect(n);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(border: Border.all(color: DF.line), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              color: i.isEven ? DF.surfaceMuted : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final cell in rows[i].children.where((c) => c.tag == 'td' || c.tag == 'th'))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text.rich(
                          TextSpan(
                            children: cell.children
                                .map((c) => _span(
                                    c,
                                    _base.copyWith(
                                      fontSize: fontSize - 1.5,
                                      height: 1.45,
                                      fontWeight: cell.tag == 'th' ? FontWeight.w600 : null,
                                    )))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  InlineSpan _span(_Node n, TextStyle style) {
    if (n.tag == '#text') return TextSpan(text: n.text.replaceAll(RegExp(r'\s+'), ' '), style: style);
    if (n.tag == 'br') return TextSpan(text: '\n', style: style);
    if (n.tag == 'img') {
      final src = Config.url(n.attrs['src']);
      return WidgetSpan(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: NetImage(src)));
    }
    var s = style;
    switch (n.tag) {
      case 'strong':
      case 'b':
        s = s.copyWith(fontWeight: FontWeight.w700, color: DF.ink900);
        break;
      case 'em':
      case 'i':
        s = s.copyWith(fontStyle: FontStyle.italic);
        break;
      case 'u':
        s = s.copyWith(decoration: TextDecoration.underline);
        break;
      case 'a':
        s = s.copyWith(color: DF.primary700, decoration: TextDecoration.underline, decorationColor: DF.primary300);
        final href = n.attrs['href'] ?? '';
        return TextSpan(
          style: s,
          recognizer: href.isEmpty ? null : (TapGestureRecognizer()..onTap = () => onLink?.call(href)),
          children: n.children.map((c) => _span(c, s)).toList(),
        );
    }
    // Block tags met inside a line (a <p> inside a <td>) read as a new line.
    final isBlock = _blockTags.contains(n.tag);
    return TextSpan(
      style: s,
      children: [
        ...n.children.map((c) => _span(c, s)),
        if (isBlock) TextSpan(text: '\n', style: s),
      ],
    );
  }
}
