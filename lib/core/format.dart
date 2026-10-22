/// Formatting the way the website prints things (lib/utils.js).

/// ₹12,499 — Indian digit grouping, no decimals, as `formatPrice` does.
String formatPrice(num? value) {
  if (value == null) return '';
  final n = value.round();
  final negative = n < 0;
  var s = n.abs().toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return '${negative ? '-' : ''}₹$s';
}

num toNum(dynamic v, [num fallback = 0]) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? fallback;
  return fallback;
}

int toInt(dynamic v, [int fallback = 0]) => toNum(v, fallback).toInt();

String str(dynamic v) => v == null ? '' : '$v';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

/// "08 Oct 2026"
String formatDate(dynamic value) {
  DateTime? d;
  if (value is num) d = DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String && value.isNotEmpty) d = DateTime.tryParse(value);
  if (d == null) return str(value);
  d = d.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

/// Strips tags and decodes the common entities, for plain-text previews.
String plainText(String? html) {
  if (html == null) return '';
  return html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&plusmn;', '±')
      .replaceAll('&deg;', '°')
      .replaceAll('&times;', '×')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final mobilePattern = RegExp(r'^[6-9]\d{9}$');
final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$');
final pinPattern = RegExp(r'^[1-9]\d{5}$');

/// The last 10 digits, as the site's `normaliseMobile` reads a number.
String normaliseMobile(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}
