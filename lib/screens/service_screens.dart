import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_tabs.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/net_image.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

/// Booking a service visit: the service list (components/services/ServiceBooking.jsx
/// on the service landing pages), the basket (/book, ServiceCart.jsx), the
/// one-page booking (/book/checkout, ServiceCheckout.jsx + BookingModals.jsx)
/// and the confirmation (/book/done).

/// One visit covers a household or a small office; more is a site survey.
const _maxPerService = 5;

/// SERVICE_GROUPS in lib/services/wizard.js.
const _groupLabels = {'2': 'Repair / Service', '1': 'Installation / Uninstallation', '3': 'AMC Plans'};

/// The page title each group's landing page carries.
const _groupTitles = {'2': 'Water Purifier Service', '1': 'Water Purifier Installation', '3': 'Water Purifier AMC'};

/// The last booking made on this phone, so /book/done can show it.
const _lastBookingKey = 'df-last-booking';

IconData _groupIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('amc')) return Icons.event_available_outlined;
  if (l.contains('install')) return Icons.handyman_outlined;
  return Icons.build_outlined;
}

/// One white block of the page on the grey canvas, 8px apart.
class _Section extends StatelessWidget {
  const _Section({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        color: Colors.white,
        padding: padding,
        child: child,
      );
}

const _heading = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900);

/* ------------------------------------------------------------- services */

/// The service landing page's booking block (ServiceBooking.jsx), on a phone:
/// a compact banner, the service types as chips, the services by group and
/// the cart bar at the bottom.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.group = '2'});
  final String group;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  Map<String, dynamic>? data;
  String? error;
  String? active;
  final Map<String, GlobalKey> _groupKeys = {};
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    final res = await Api.instance.get('/api/mobile/services');
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        data = res.map;
      } else {
        error = res.error;
      }
    });
  }

  List<Map<String, dynamic>> get services => mapsOf(data?['services']);

  /// Adding a service asks for a number first, as the site does: the visit
  /// is booked against it.
  Future<void> _setQty(Map<String, dynamic> service, int qty) async {
    final state = AppScope.read(context);
    if (qty > 0 && !state.signedIn) {
      final ok = await showBookingSignIn(context);
      if (ok && mounted) AppScope.read(context).setServiceQty(service, 1);
      return;
    }
    state.setServiceQty(service, min(qty, _maxPerService));
  }

  /// From the chip strip: bring that service type into view.
  void _show(String groupId) {
    setState(() => active = groupId);
    final ctx = _groupKeys[groupId]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ids = services.map((s) => str(s['id'])).toSet();
    final lines = state.serviceCart.where((l) => ids.contains(l.id)).toList();
    final count = lines.fold<int>(0, (n, l) => n + l.qty);
    final total = lines.fold<num>(0, (n, l) => n + l.price * l.qty);
    final saved = lines.fold<num>(0, (n, l) => n + max<num>(0, l.mrp - l.price) * l.qty);

    return DFScaffold(
      title: 'Book a service',
      bottomBar: count > 0
          ? _CartBar(
              note: '$count service${count == 1 ? '' : 's'}${saved > 0 ? ' · saving ${formatPrice(saved)}' : ''}',
              total: total,
              label: 'Checkout',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceCartScreen())),
            )
          : null,
      body: data == null ? LoadState(error: error, onRetry: _load) : _body(state),
    );
  }

  Widget _body(AppState state) {
    final heading = _groupTitles[widget.group] ?? 'Water Purifier Service';
    var groups = mapsOf(data!['groups']);
    if (groups.isEmpty) groups = _groupLabels.entries.map((e) => {'id': e.key, 'label': e.value}).toList();
    // The group this page is about comes first.
    groups.sort((a, b) => (str(a['id']) == widget.group ? 0 : 1) - (str(b['id']) == widget.group ? 0 : 1));
    final grouped = [
      for (final g in groups) (g, services.where((s) => str(s['group']) == str(g['id'])).toList()),
    ].where((e) => e.$2.isNotEmpty).toList();
    final brand = state.brand;
    final phone = str(brand['phone']).isNotEmpty ? str(brand['phone']) : Config.phone;
    final tel = str(brand['phoneRaw']).isNotEmpty ? str(brand['phoneRaw']) : Config.phoneRaw;

    if (services.isEmpty) return const LoadState(error: 'Services are unavailable right now.');
    final current = active ?? (grouped.isNotEmpty ? str(grouped.first.$1['id']) : null);

    return RefreshIndicator(
      color: DF.primary600,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Section(
            child: _Banner(
              title: heading,
              phone: phone,
              onBook: () {
                final ctx = _listKey.currentContext;
                if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400));
              },
              onCall: () => Native.call(tel),
            ),
          ),
          if (grouped.length > 1)
            Container(
              margin: const EdgeInsets.only(top: 8),
              color: Colors.white,
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: grouped.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final g = grouped[i].$1;
                  final id = str(g['id']);
                  return Center(
                    child: DFChip(
                      str(g['label']),
                      icon: _groupIcon(str(g['label'])),
                      selected: id == current,
                      onTap: () => _show(id),
                    ),
                  );
                },
              ),
            ),
          Column(
            key: _listKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (g, items) in grouped)
                _Section(
                  key: _groupKeys.putIfAbsent(str(g['id']), () => GlobalKey()),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(_groupIcon(str(g['label'])), size: 17, color: DF.primary700),
                          const SizedBox(width: 8),
                          Expanded(child: Text(str(g['label']), style: _heading)),
                          Text('${items.length}', style: const TextStyle(fontSize: 13, color: DF.ink400)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final (i, s) in items.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _ServiceItem(
                          s: s,
                          qty: state.serviceQty(str(s['id'])),
                          setQty: (n) => _setQty(s, n),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The page's own banner, compact: its title, one line and how to book.
class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.phone, required this.onBook, required this.onCall});
  final String title;
  final String phone;
  final VoidCallback onBook;
  final VoidCallback onCall;

  static const _points = [
    (Icons.water_drop_outlined, '100% pure water'),
    (Icons.memory, 'Advanced RO'),
    (Icons.build_outlined, 'Expert service'),
    (Icons.verified_user_outlined, 'Quality assured'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: DF.primary600, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.water_drop_outlined, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.25)),
                    const SizedBox(height: 2),
                    const Text('Premium service package · pay after the visit', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (icon, text) in _points)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: DF.primary600),
                    const SizedBox(width: 4),
                    Text(text, style: const TextStyle(fontSize: 12, color: DF.ink700)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: onBook,
                    style: FilledButton.styleFrom(
                      backgroundColor: DF.primary700,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Book service now'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone, size: 14),
                    label: Text(phone, overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DF.primary700,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: const BorderSide(color: DF.primary200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One service row: picture left; name, two points and the price; Add or the stepper right.
class _ServiceItem extends StatefulWidget {
  const _ServiceItem({required this.s, required this.qty, required this.setQty});
  final Map<String, dynamic> s;
  final int qty;
  final ValueChanged<int> setQty;

  @override
  State<_ServiceItem> createState() => _ServiceItemState();
}

class _ServiceItemState extends State<_ServiceItem> {
  bool more = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final qty = widget.qty;
    final price = toNum(s['price']);
    final mrp = toNum(s['mrp']);
    final all = (s['points'] as List? ?? const []).map((e) => '$e').toList();
    final points = more ? all : all.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumb(str(s['image']), 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(s['name']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900, height: 1.3)),
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final p in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 6),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(color: DF.ink300, shape: BoxShape.circle),
                          ),
                          Expanded(
                            child: Text(p,
                                maxLines: more ? null : 1,
                                overflow: more ? null : TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, height: 1.35, color: DF.ink500)),
                          ),
                        ],
                      ),
                    ),
                ],
                if (all.length > 2)
                  InkWell(
                    onTap: () => setState(() => more = !more),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(more ? 'Show less' : '+${all.length - 2} more',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DF.primary700)),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 6,
                        children: [
                          Text(formatPrice(price), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: DF.ink900)),
                          if (mrp > price)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Text(formatPrice(mrp),
                                  style: const TextStyle(fontSize: 12, color: DF.ink400, decoration: TextDecoration.lineThrough)),
                            ),
                        ],
                      ),
                    ),
                    if (qty > 0)
                      _Stepper(qty: qty, onChange: widget.setQty)
                    else
                      SizedBox(
                        width: 88,
                        height: 34,
                        child: OutlinedButton(
                          onPressed: () => widget.setQty(1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DF.primary700,
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: DF.primary500),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('ADD'),
                        ),
                      ),
                  ],
                ),
                if (qty >= _maxPerService)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: () => Native.call('9311587716'),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Maximum $_maxPerService per booking. For more, call ',
                          style: TextStyle(fontSize: 12, color: DF.ink400),
                          children: [TextSpan(text: '+91-9311587716', style: TextStyle(fontWeight: FontWeight.w500, color: DF.primary700))],
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
}

/// − qty + in the brand blue (ServiceBooking.jsx `Stepper`).
class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onChange});
  final int qty;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    const h = 34.0;
    Widget btn(IconData icon, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: h,
            child: Icon(icon, size: 14, color: onTap == null ? const Color(0x80FFFFFF) : Colors.white),
          ),
        );
    return Container(
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: DF.primary600, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, () => onChange(qty - 1)),
          SizedBox(
            width: 24,
            child: Text('$qty',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          btn(Icons.add, qty >= _maxPerService ? null : () => onChange(qty + 1)),
        ],
      ),
    );
  }
}

/// The sticky bar under the service list: count, saving, total and the way on.
class _CartBar extends StatelessWidget {
  const _CartBar({required this.note, required this.total, required this.label, required this.onPressed});
  final String note;
  final num total;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatPrice(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                Text(note, style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: DF.primary700,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(label), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------- sign in */

/// Signing in to book a service (components/services/BookingSignIn.jsx): a
/// number, a sum to prove there is a person there, and the code that follows.
/// Resolves true once signed in.
Future<bool> showBookingSignIn(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const SingleChildScrollView(child: _BookingSignIn()),
    ),
  );
  return ok == true;
}

class _BookingSignIn extends StatefulWidget {
  const _BookingSignIn();

  @override
  State<_BookingSignIn> createState() => _BookingSignInState();
}

class _BookingSignInState extends State<_BookingSignIn> {
  final _rand = Random();
  final mobile = TextEditingController();
  final answer = TextEditingController();
  final code = TextEditingController();
  String step = 'number'; // number | code
  late (int, int) maths = _sum();
  bool busy = false;
  String error = '';
  int seconds = 0;
  Timer? _timer;

  (int, int) _sum() => (2 + _rand.nextInt(8), 2 + _rand.nextInt(8));

  String get digits => mobile.text.replaceAll(RegExp(r'\D'), '');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _countdown() {
    _timer?.cancel();
    seconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => seconds--);
      if (seconds <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool again = false}) async {
    if (digits.length != 10) return setState(() => error = 'Enter your 10-digit mobile number.');
    if (!again && int.tryParse(answer.text) != maths.$1 + maths.$2) {
      return setState(() {
        error = 'That sum is not right.';
        maths = _sum();
        answer.clear();
      });
    }
    setState(() {
      busy = true;
      error = '';
    });
    final res = await Api.instance.post('/api/auth/request-otp', {'mode': 'book', 'mobile': digits});
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      return setState(() => error = res.map['error'] is String ? res.error : 'Could not send the code. Try again.');
    }
    setState(() => step = 'code');
    // The service refuses another code for a minute.
    _countdown();
  }

  Future<void> _verify() async {
    final otp = code.text.replaceAll(RegExp(r'\D'), '');
    if (otp.length < 4) return setState(() => error = 'Enter the code from the message.');
    setState(() {
      busy = true;
      error = '';
    });
    final res = await Api.instance.post('/api/auth/verify-otp', {'mode': 'book', 'mobile': digits, 'otp': otp});
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) return setState(() => error = res.map['error'] is String ? res.error : 'That code did not work.');
    final state = AppScope.read(context);
    final user = res.map['user'];
    if (user is Map) {
      await state.signedInAs(user);
    } else {
      await state.refreshSession();
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final numberStep = step == 'number';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close, size: 18, color: DF.ink400)),
          ),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
              child: const Icon(Icons.phone_outlined, size: 22, color: DF.primary700),
            ),
          ),
          const SizedBox(height: 16),
          Text(numberStep ? 'Enter your phone number' : 'Enter the code',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: DF.ink900)),
          const SizedBox(height: 4),
          Text(numberStep ? 'We’ll send you a text with a verification code' : 'Sent to +91 $digits',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: DF.ink400)),
          const SizedBox(height: 20),
          if (numberStep) ...[
            TextField(
              controller: mobile,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              style: const TextStyle(fontSize: 15, color: DF.ink900),
              decoration: InputDecoration(
                hintText: '10-digit mobile number',
                prefixIcon: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    color: DF.surfaceMuted,
                    border: Border(right: BorderSide(color: DF.lineStrong)),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                  ),
                  alignment: Alignment.center,
                  width: 52,
                  child: const Text('+91', style: TextStyle(fontSize: 15, color: DF.ink500)),
                ),
                prefixIconConstraints: const BoxConstraints(minHeight: 46),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DF.surfaceMuted.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DF.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 15, color: DF.primary600),
                      SizedBox(width: 8),
                      Text('Security check', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.ink700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DF.lineStrong),
                        ),
                        child: Text('${maths.$1} + ${maths.$2} = ?',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DF.ink700)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: answer,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                          onSubmitted: (_) => _sendCode(),
                          decoration: const InputDecoration(hintText: 'Answer'),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          maths = _sum();
                          answer.clear();
                        }),
                        icon: const Icon(Icons.refresh, size: 18, color: DF.ink400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              onSubmitted: (_) => _verify(),
              style: const TextStyle(fontSize: 18, letterSpacing: 5.4, color: DF.ink900),
              decoration: const InputDecoration(hintText: '4-digit code'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    step = 'number';
                    code.clear();
                    error = '';
                  }),
                  child: const Text('Change number', style: TextStyle(fontSize: 13, color: DF.ink400)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: seconds > 0 || busy ? null : () => _sendCode(again: true),
                  child: Text(seconds > 0 ? 'Resend in ${seconds}s' : 'Resend code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: seconds > 0 ? DF.ink300 : DF.primary700)),
                ),
              ],
            ),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: DF.danger)),
          ],
          const SizedBox(height: 20),
          PrimaryButton(numberStep ? 'Continue' : 'Verify and continue',
              height: 44, loading: busy, onPressed: () => numberStep ? _sendCode() : _verify()),
          const SizedBox(height: 12),
          const Text('Your number is used for this booking and to update you about the visit.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DF.ink400)),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------- small parts */

/// A white block with a header row: "Services (2)", "Customer details" …
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.icon, this.done = false, this.action, this.muted = false});
  final String title;
  final IconData? icon;
  final bool done;
  final Widget? action;
  final bool muted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 17, color: muted ? DF.ink300 : DF.primary700), const SizedBox(width: 8)],
                Flexible(
                  child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: muted ? DF.ink400 : DF.ink900)),
                ),
                if (done) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, size: 16, color: DF.primary600)],
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

Widget _thumb(String image, double size) => Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(10)),
      child: image.isEmpty ? const Icon(Icons.build_outlined, size: 18, color: DF.ink300) : NetImage(Config.url(image), fit: BoxFit.cover),
    );

/// The cart's plain − qty + with a bin beside it (ServiceCart.jsx).
Widget _lineStepper(BuildContext context, ServiceLine l, {bool small = false}) {
  final state = AppScope.read(context);
  final map = l.toJson();
  Widget btn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 4 : 6),
          child: Icon(icon, size: small ? 13 : 14, color: DF.primary700),
        ),
      );
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        decoration: BoxDecoration(border: Border.all(color: DF.primary200), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.remove, () => state.setServiceQty(map, l.qty - 1)),
            SizedBox(
              width: small ? 26 : 30,
              child: Text('${l.qty}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: small ? 13.5 : 14, fontWeight: FontWeight.w600, color: DF.ink900)),
            ),
            btn(Icons.add, () => state.setServiceQty(map, l.qty + 1)),
          ],
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => state.setServiceQty(map, 0),
        tooltip: 'Remove ${l.name}',
        icon: Icon(Icons.delete_outline, size: small ? 16 : 17, color: DF.ink300),
      ),
    ],
  );
}

Widget _emptyCart(BuildContext context, {bool withNote = true}) => _Section(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: DF.primary50),
            child: const Icon(Icons.shopping_cart_outlined, size: 32, color: DF.ink300),
          ),
          const SizedBox(height: 14),
          const Text('Your cart is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
          if (withNote) ...[
            const SizedBox(height: 4),
            const Text('Add a service to book a visit.', style: TextStyle(fontSize: 13, color: DF.ink400)),
          ],
          const SizedBox(height: 18),
          PrimaryButton('Browse services', icon: null, height: 44, onPressed: () => _browse(context)),
        ],
      ),
    );

/// "Browse services" / "Add another service" — the service list.
void _browse(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServicesScreen()));

/* --------------------------------------------------------------- /book */

/// The services picked so far, before the booking itself
/// (app/(booking)/book/page.jsx + components/services/ServiceCart.jsx).
class ServiceCartScreen extends StatelessWidget {
  const ServiceCartScreen({super.key});

  static const _assurances = [
    (Icons.account_balance_wallet_outlined, 'Nothing is charged now — pay the technician after the visit'),
    (Icons.event_available_outlined, 'We call to confirm the time before anyone sets off'),
    (Icons.verified_outlined, 'Trained technicians, genuine parts'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lines = state.serviceCart;
    final who = state.user;

    return DFScaffold(
      title: 'Service cart',
      bottomBar: lines.isEmpty
          ? null
          : _CartBar(
              note: '${state.serviceCount} service${state.serviceCount == 1 ? '' : 's'} · visit free',
              total: state.serviceTotal,
              label: 'Book Service',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceCheckoutScreen())),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (lines.isEmpty)
            _emptyCart(context)
          else ...[
            // what is booked
            _Section(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('${lines.length} ${lines.length == 1 ? 'service' : 'services'}', style: _heading),
                      const Spacer(),
                      if (who != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 13, color: DF.primary800),
                              const SizedBox(width: 6),
                              Text(who.name.isNotEmpty ? who.name : '+91 ${who.mobile}',
                                  style: const TextStyle(fontSize: 12.5, color: DF.primary800)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final (i, l) in lines.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _thumb(l.image, 60),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.name,
                                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900, height: 1.3)),
                                const SizedBox(height: 2),
                                Text(
                                  [if (l.group.isNotEmpty) _groupLabels[l.group] ?? l.group, '${formatPrice(l.price)} each'].join(' · '),
                                  style: const TextStyle(fontSize: 12.5, color: DF.ink400),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(formatPrice(l.price * l.qty),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)),
                                    const Spacer(),
                                    _lineStepper(context, l, small: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  InkWell(
                    onTap: () => _browse(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: DF.primary700),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text('Add another service',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.primary700)),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: DF.ink300),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // the summary
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Summary', style: _heading),
                  const SizedBox(height: 10),
                  _row('Services (${state.serviceCount})', formatPrice(state.serviceTotal)),
                  const SizedBox(height: 6),
                  _row('Visit charge', 'Free',
                      valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.primary600)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                  Row(
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DF.ink900)),
                      const Spacer(),
                      Text(formatPrice(state.serviceTotal),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.primary800)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  for (final (icon, text) in _assurances)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 14, color: DF.primary600)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35, color: DF.ink400))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _row(String label, String value, {TextStyle? valueStyle}) => Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: DF.ink500)),
          const Spacer(),
          Text(value, style: valueStyle ?? const TextStyle(fontSize: 14, color: DF.ink900)),
        ],
      );
}

/* ------------------------------------------------------ /book/checkout */

/// Booking the visit — one page, four things to settle
/// (app/(booking)/book/checkout/page.jsx + components/services/ServiceCheckout.jsx).
class ServiceCheckoutScreen extends StatefulWidget {
  const ServiceCheckoutScreen({super.key});

  @override
  State<ServiceCheckoutScreen> createState() => _ServiceCheckoutScreenState();
}

class _ServiceCheckoutScreenState extends State<ServiceCheckoutScreen> {
  static const _steps = ['Details', 'Address', 'Schedule', 'Payment'];
  static const _assurances = [
    (Icons.verified_user_outlined, 'Secure'),
    (Icons.event_available_outlined, 'Flexible timing'),
    (Icons.verified_outlined, 'Verified pros'),
  ];

  List<String> states = [];
  List<Map<String, dynamic>> addresses = [];
  Map<String, dynamic>? address;
  Map<String, String>? when; // date, slot, label
  bool payOnline = false;
  String payReason = '';
  bool sending = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    // Booking needs the customer signed in; the site sends them back to /book.
    if (!AppScope.read(context).signedIn) {
      final ok = await showBookingSignIn(context);
      if (!ok) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    final results = await Future.wait([
      Api.instance.get('/api/services/payment-options'),
      Api.instance.get('/api/services/address'),
      Api.instance.get('/api/mobile/services'),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0].ok) {
        payOnline = results[0].map['online'] == true;
        payReason = str(results[0].map['reason']);
      }
      final list = mapsOf(results[1].map['addresses']);
      if (list.isNotEmpty) addresses = list;
      states = ((results[2].map['states'] as List?) ?? const []).map((e) => '$e').toList();
    });
  }

  Future<void> _pickAddress() async {
    final picked = await showDFSheet<Object>(
      context,
      title: 'Saved addresses',
      subtitle: 'Pick where the technician should come.',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'new'),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add a new address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DF.primary700,
                side: const BorderSide(color: DF.primary300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (addresses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: DF.line)),
              child: const Text('No saved addresses on this number yet — add one above.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: DF.ink400)),
            )
          else
            for (final a in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, a),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: DF.line)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                          child: const Icon(Icons.location_on_outlined, size: 15, color: DF.primary700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(a['label']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: DF.ink900)),
                              const SizedBox(height: 2),
                              Text(str(a['line']), style: const TextStyle(fontSize: 13, height: 1.35, color: DF.ink500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    if (!mounted) return;
    if (picked == 'new') {
      _addAddress();
    } else if (picked is Map<String, dynamic>) {
      setState(() => address = picked);
    }
  }

  Future<void> _addAddress() async {
    final user = AppScope.read(context).user;
    final saved = await showDFSheet<(List<Map<String, dynamic>>, Map<String, dynamic>?)>(
      context,
      title: 'Address details',
      subtitle: 'Where should the technician come?',
      builder: (_) => _AddressForm(states: states, name: user?.name ?? '', mobile: user?.mobile ?? ''),
    );
    if (saved == null || !mounted) return;
    setState(() {
      addresses = saved.$1;
      if (saved.$2 != null) address = saved.$2;
    });
  }

  Future<void> _schedule() async {
    final picked = await showDFSheet<Map<String, String>>(
      context,
      title: 'When should the technician arrive?',
      subtitle: 'Pick a day, then a time window.',
      builder: (_) => const _SchedulePicker(),
    );
    if (picked != null && mounted) setState(() => when = picked);
  }

  Future<void> _book(String payment) async {
    final a = address;
    final w = when;
    if (a == null || w == null) return;
    final state = AppScope.read(context);
    final user = state.user;
    final lines = List<ServiceLine>.from(state.serviceCart);
    setState(() {
      sending = true;
      error = '';
    });
    final label = str(a['label']);
    final body = {
      'name': label.isNotEmpty && label != 'Saved address' ? label : (user?.name ?? ''),
      'mobile': user?.mobile ?? '',
      'email': user?.email ?? '',
      'houseNo': str(a['houseNo']).isNotEmpty ? str(a['houseNo']) : str(a['line']),
      'area': str(a['street']),
      'nearBy': str(a['landmark']),
      'city': str(a['city']),
      'state': str(a['state']),
      'pincode': str(a['pincode']),
      'addressId': str(a['remoteId']),
      'premises': '1',
      'date': w['date'],
      'slot': w['slot'],
      'payment': payment,
      'serviceGroup': lines.isNotEmpty ? lines.first.group : '',
      'path': '/book',
      'services': [
        for (final l in lines) {'id': l.id, 'name': l.name, 'qty': l.qty, 'price': l.price}
      ],
    };
    final res = await Api.instance.post('/api/services/book', body);
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        sending = false;
        error = res.map['error'] is String ? res.error : 'Could not book the visit. Please try again.';
      });
      return;
    }

    final ref = str(res.map['ref']);
    final redirect = str(res.map['redirect']);
    // Kept so the confirmation can show what was booked: the site reads it
    // back from its database, which has no app endpoint.
    await Store.instance.set(_lastBookingKey, {
      'ref': ref,
      'mobile': user?.mobile ?? '',
      'services': [
        for (final l in lines) {'id': l.id, 'name': l.name, 'qty': l.qty, 'price': l.price}
      ],
      'amount': lines.fold<num>(0, (n, l) => n + l.price * l.qty),
      'date': w['date'],
      'slot': w['slot'],
      'houseNo': body['houseNo'],
      'area': body['area'],
      'city': body['city'],
      'state': body['state'],
      'pincode': body['pincode'],
      'payment': redirect.isNotEmpty ? 'online' : 'after',
      'paymentUrl': redirect,
      'duplicate': res.map['duplicate'] == true,
    });
    if (!mounted) return;
    state.clearServiceCart();

    // Straight to the payment page; the booking is already written and sits
    // unpaid until the money arrives.
    if (redirect.isNotEmpty) await Native.open(redirect, context: context);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BookingDoneScreen(ref: ref)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lines = state.serviceCart;
    final user = state.user;
    final step = address == null
        ? 1
        : when == null
            ? 2
            : 3;

    return DFScaffold(
      title: 'Book your visit',
      checkoutMode: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (lines.isEmpty && !sending)
            _emptyCart(context, withNote: false)
          else ...[
            _Section(child: _bar(step)),
            _Card(
              title: 'Services (${lines.length})',
              icon: Icons.build_outlined,
              done: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, l) in lines.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            _thumb(l.image, 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900, height: 1.3)),
                                  const SizedBox(height: 4),
                                  _lineStepper(context, l, small: true),
                                ],
                              ),
                            ),
                            Text(formatPrice(l.price * l.qty),
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DF.ink900)),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DF.ink900)),
                          const Spacer(),
                          Text(formatPrice(state.serviceTotal),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.primary800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Card(
              title: 'Customer details',
              icon: Icons.person_outline,
              done: user != null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  children: [
                    _detail('Name', user?.name.isNotEmpty == true ? user!.name : '—'),
                    _detail('Phone', user?.mobile.isNotEmpty == true ? '+91 ${user!.mobile}' : '—'),
                    if (user?.email.isNotEmpty == true) _detail('Email', user!.email),
                  ],
                ),
              ),
            ),
            _Card(
              title: 'Service address',
              icon: Icons.location_on_outlined,
              done: address != null,
              action: address != null ? _change(_pickAddress) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: address != null
                    ? Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 14, height: 1.5, color: DF.ink500),
                          children: [
                            TextSpan(
                                text: '${str(address!['label'])}\n', style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink900)),
                            TextSpan(text: str(address!['line'])),
                          ],
                        ),
                      )
                    : _stepButton(Icons.location_on_outlined, 'Select address', _pickAddress),
              ),
            ),
            _Card(
              title: 'Appointment time',
              icon: Icons.event_available_outlined,
              done: when != null,
              muted: address == null,
              action: when != null ? _change(_schedule) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: when != null
                    ? Text(when!['label'] ?? '', style: const TextStyle(fontSize: 14, color: DF.ink700))
                    : _stepButton(Icons.schedule, 'Select date & time', address == null ? null : _schedule),
              ),
            ),
            _Card(
              title: 'Payment options',
              icon: Icons.account_balance_wallet_outlined,
              muted: when == null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepButton(
                      Icons.verified_user_outlined,
                      payOnline ? 'Pay ${formatPrice(state.serviceTotal)} now' : 'Pay online (unavailable)',
                      when == null || sending || !payOnline ? null : () => _book('online'),
                      chevron: payOnline,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: when == null || sending ? null : () => _book('after'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DF.ink800,
                          disabledForegroundColor: DF.ink300,
                          side: BorderSide(color: when == null ? DF.line : DF.lineStrong),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            sending
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.account_balance_wallet_outlined, size: 16),
                            const SizedBox(width: 8),
                            const Text('Pay after service'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payOnline
                          ? 'Paying now is optional — the technician takes cash, UPI or card after the visit either way.'
                          : payReason == 'not-signed-in-with-otp'
                              ? 'Paying online needs a fresh sign-in with an OTP — or pay the technician after the visit.'
                              : 'Online payment is not available for this booking; the technician takes cash, UPI or card after the visit.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: DF.ink400),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: DF.danger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                        child: Text(error, style: const TextStyle(fontSize: 13.5, color: DF.danger)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final (icon, label) in _assurances)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: DF.primary600),
                            const SizedBox(width: 4),
                            Text(label, style: const TextStyle(fontSize: 12.5, color: DF.ink500)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: DF.ink400),
                      children: [
                        TextSpan(text: 'Cancellation policy — ', style: TextStyle(fontWeight: FontWeight.w600, color: DF.ink700)),
                        TextSpan(
                          text: 'free if you cancel more than 12 hours before the visit, or if no technician has been assigned yet. '
                              'A fee applies otherwise.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(int at) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, label) in _steps.indexed) ...[
          SizedBox(
            width: 64,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < at ? DF.primary600 : Colors.white,
                    border: Border.all(
                        color: i < at
                            ? DF.primary600
                            : i == at
                                ? DF.primary600
                                : DF.line,
                        width: 2),
                    boxShadow: i == at ? const [BoxShadow(color: DF.primary100, spreadRadius: 4)] : null,
                  ),
                  alignment: Alignment.center,
                  child: i < at
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: i == at ? DF.primary700 : DF.ink300)),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1,
                      fontWeight: i == at ? FontWeight.w600 : FontWeight.w400,
                      color: i == at ? DF.ink900 : DF.ink400,
                    )),
              ],
            ),
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 17),
                height: 2,
                decoration: BoxDecoration(color: i < at ? DF.primary600 : DF.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: DF.ink400)),
            const SizedBox(width: 16),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, color: DF.ink900))),
          ],
        ),
      );

  Widget _change(VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.primary700)),
      );

  Widget _stepButton(IconData icon, String label, VoidCallback? onTap, {bool chevron = true}) => SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: DF.primary600,
            disabledBackgroundColor: DF.line,
            disabledForegroundColor: DF.ink400,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (chevron) ...[const SizedBox(width: 6), const Icon(Icons.chevron_right, size: 16)],
            ],
          ),
        ),
      );
}

/// "Address details" — a new address for the visit (BookingModals.jsx `AddressForm`).
/// Pops `(addresses, chosen)` once saved.
class _AddressForm extends StatefulWidget {
  const _AddressForm({required this.states, required this.name, required this.mobile});
  final List<String> states;
  final String name;
  final String mobile;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  String type = 'home';
  late final name = TextEditingController(text: widget.name);
  late final phone = TextEditingController(text: widget.mobile);
  final altPhone = TextEditingController();
  final pincode = TextEditingController();
  final houseNo = TextEditingController();
  final street = TextEditingController();
  final landmark = TextEditingController();
  String state = '';
  String city = '';
  List<String> cities = [];
  bool busy = false;
  bool lookingUp = false;
  String error = '';

  Future<void> _loadCities(String s) async {
    if (s.isEmpty) return setState(() => cities = []);
    final res = await Api.instance.get('/api/services/cities', query: {'state': s});
    if (!mounted) return;
    setState(() => cities = ((res.map['cities'] as List?) ?? const []).map((e) => '$e').toList());
  }

  /// Six digits is enough to know the city and the state; nobody should type them.
  Future<void> _fillFromPincode(String pin) async {
    if (!pinPattern.hasMatch(pin)) return;
    setState(() => lookingUp = true);
    final res = await Api.instance.get('/api/pincode/$pin');
    if (!mounted) return;
    setState(() {
      lookingUp = false;
      if (res.ok) {
        if (str(res.map['state']).isNotEmpty) state = str(res.map['state']);
        if (str(res.map['city']).isNotEmpty) city = str(res.map['city']);
      }
    });
    _loadCities(state);
  }

  Future<void> _save() async {
    setState(() => error = '');
    final values = {
      'name': name.text,
      'phone number': phone.text,
      'pin code': pincode.text,
      'state': state,
      'city': city,
      'house or flat number': houseNo.text,
      'street': street.text,
    };
    for (final e in values.entries) {
      if (e.value.trim().isEmpty) return setState(() => error = 'Please enter the ${e.key}.');
    }
    if (!mobilePattern.hasMatch(phone.text)) return setState(() => error = 'Enter a valid 10-digit phone number.');
    if (!pinPattern.hasMatch(pincode.text)) return setState(() => error = 'Enter a valid 6-digit pin code.');

    setState(() => busy = true);
    final res = await Api.instance.post('/api/services/address', {
      'type': type,
      'name': name.text.trim(),
      'phone': phone.text,
      'altPhone': altPhone.text,
      'pincode': pincode.text,
      'state': state,
      'city': city,
      'houseNo': houseNo.text.trim(),
      'street': street.text.trim(),
      'landmark': landmark.text.trim(),
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) return setState(() => error = res.map['error'] is String ? res.error : 'Could not save the address.');
    final list = mapsOf(res.map['addresses']);
    final chosen = res.map['chosen'] is Map ? Map<String, dynamic>.from(res.map['chosen'] as Map) : (list.isNotEmpty ? list.first : null);
    Navigator.pop(context, (list, chosen));
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: DF.ink700),
          children: [if (required) const TextSpan(text: '*', style: TextStyle(color: DF.danger))],
        )),
      );

  Widget _input(TextEditingController c, String hint, {IconData? icon, bool digits = false, int? max, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        keyboardType: digits ? TextInputType.number : null,
        inputFormatters: [
          if (digits) FilteringTextInputFormatter.digitsOnly,
          if (max != null) LengthLimitingTextInputFormatter(max),
        ],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: DF.ink900),
        decoration: InputDecoration(hintText: hint, prefixIcon: icon == null ? null : Icon(icon, size: 15, color: DF.ink300)),
      );

  Widget _select(String value, List<String> items, String hint, ValueChanged<String?>? onChanged) {
    final all = [...items, if (value.isNotEmpty && !items.contains(value)) value];
    return DropdownButtonFormField<String>(
      key: ValueKey('$hint-$value-${all.length}'),
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(color: DF.ink300, fontSize: 14)),
      items: all.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: DF.ink900),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Address type'),
        Row(
          children: [
            for (final (id, label, icon) in const [
              ('home', 'Home', Icons.location_on_outlined),
              ('office', 'Office', Icons.business_outlined)
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => type = id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: type == id ? DF.primary600 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: type == id ? DF.primary600 : DF.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: type == id ? Colors.white : DF.ink700),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: type == id ? FontWeight.w600 : FontWeight.w500,
                              color: type == id ? Colors.white : DF.ink700,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap,
        _label('Name', required: true),
        _input(name, 'Full name', icon: Icons.person_outline),
        gap,
        _label('Phone number', required: true),
        _input(phone, '10-digit number', icon: Icons.phone_outlined, digits: true, max: 10),
        gap,
        _label('Alternate phone'),
        _input(altPhone, 'Optional', digits: true, max: 10),
        gap,
        _label('Pin code', required: true),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            _input(pincode, '6-digit pin code', digits: true, max: 6, onChanged: (pin) {
              if (pin.length == 6) _fillFromPincode(pin);
            }),
            if (lookingUp)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: DF.primary500)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('City and state fill in themselves.', style: TextStyle(fontSize: 11.5, color: DF.ink400)),
        gap,
        _label('State', required: true),
        _select(state, widget.states, 'Select state', (v) {
          setState(() {
            state = v ?? '';
            city = '';
          });
          _loadCities(state);
        }),
        gap,
        _label('City', required: true),
        _select(city, cities, state.isEmpty ? 'Choose a state first' : 'Select city',
            state.isEmpty ? null : (v) => setState(() => city = v ?? '')),
        gap,
        _label('House / flat number', required: true),
        _input(houseNo, 'House, flat or building'),
        gap,
        _label('Street', required: true),
        _input(street, 'Street, area or sector'),
        gap,
        _label('Landmark'),
        _input(landmark, 'Something nearby, so the technician finds you', icon: Icons.near_me_outlined),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DF.danger.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DF.danger.withValues(alpha: 0.3)),
            ),
            child: Text(error, style: const TextStyle(fontSize: 13, color: DF.danger)),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlineButton('Cancel',
                  height: 44, color: DF.ink700, borderColor: DF.lineStrong, onPressed: () => Navigator.pop(context)),
            ),
            const SizedBox(width: 12),
            Expanded(child: PrimaryButton('Save address', height: 44, loading: busy, onPressed: _save)),
          ],
        ),
      ],
    );
  }
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "When should the technician arrive?" — today and the four days after it,
/// then the time windows the service has free that day (`SchedulePicker`).
class _SchedulePicker extends StatefulWidget {
  const _SchedulePicker();

  @override
  State<_SchedulePicker> createState() => _SchedulePickerState();
}

class _SchedulePickerState extends State<_SchedulePicker> {
  final days = List.generate(5, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });
  DateTime? date;
  String? slot;
  List<String> slots = [];
  bool loading = false;

  Future<void> _pick(DateTime d) async {
    setState(() {
      date = d;
      slot = null;
      loading = true;
    });
    final res = await Api.instance.get('/api/services/timeslots', query: {'date': _ymd(d)});
    if (!mounted || date != d) return;
    setState(() {
      loading = false;
      slots = ((res.map['slots'] as List?) ?? const []).map((e) => '$e').toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, d) in days.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pick(d),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: date == d ? DF.primary600 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: date == d ? DF.primary600 : DF.line),
                    ),
                    child: Column(
                      children: [
                        Text(i == 0 ? 'Today' : _days[d.weekday - 1],
                            style: TextStyle(fontSize: 11, color: date == d ? const Color(0xCCFFFFFF) : DF.ink400)),
                        Text('${d.day}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: date == d ? Colors.white : DF.ink700)),
                        Text(_months[d.month - 1],
                            style: TextStyle(fontSize: 10.5, color: date == d ? const Color(0xCCFFFFFF) : DF.ink400)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (date != null) ...[
          const SizedBox(height: 20),
          const Text('Start time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.ink700)),
          const SizedBox(height: 8),
          if (loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: DF.primary600)))
          else if (slots.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: DF.line)),
              child: const Text('That day is fully booked — please try another.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: DF.ink400)),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in slots)
                    InkWell(
                      onTap: () => setState(() => slot = s),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: w,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: slot == s ? DF.primary600 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: slot == s ? DF.primary600 : DF.line),
                        ),
                        child: Text(s,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: slot == s ? FontWeight.w600 : FontWeight.w500,
                              color: slot == s ? Colors.white : DF.ink700,
                            )),
                      ),
                    ),
                ],
              );
            }),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: date == null || slot == null
                ? null
                : () {
                    final d = date!;
                    Navigator.pop(context, {
                      'date': _ymd(d),
                      'slot': slot!,
                      'label': '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day} · $slot',
                    });
                  },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm this time'),
            style: FilledButton.styleFrom(
              backgroundColor: DF.primary600,
              disabledBackgroundColor: DF.line,
              disabledForegroundColor: DF.ink400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------- /book/done */

/// After the booking (app/(booking)/book/done/page.jsx + PayLater.jsx). The
/// site reads the booking back from its database; the app shows the copy kept
/// on the phone when it was made.
class BookingDoneScreen extends StatefulWidget {
  const BookingDoneScreen({super.key, required this.ref, this.paymentFailed = false});
  final String ref;
  final bool paymentFailed;

  @override
  State<BookingDoneScreen> createState() => _BookingDoneScreenState();
}

class _BookingDoneScreenState extends State<BookingDoneScreen> with WidgetsBindingObserver {
  static const _next = [
    (Icons.phone_in_talk_outlined, 'We call you', 'Our team confirms the time slot on your number.'),
    (Icons.build_outlined, 'A technician arrives', 'Trained, with the parts for the job.'),
    (Icons.verified_user_outlined, 'You pay after', 'Cash, UPI or card once the work is done.'),
  ];

  Map<String, dynamic>? booking;
  bool busy = false;
  bool payLater = false;
  bool back = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final kept = Store.instance.get<Map>(_lastBookingKey);
    if (kept != null && (widget.ref.isEmpty || str(kept['ref']) == widget.ref)) {
      booking = Map<String, dynamic>.from(kept);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the payment page in the browser: whether it went through is
  /// known to the service only, so both ways on stay offered.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && mounted && _online && !payLater) setState(() => back = true);
  }

  bool get _online => booking?['payment'] == 'online';

  Future<void> _payLater() async {
    setState(() => busy = true);
    final res = await Api.instance.post('/api/services/pay-later', {'ref': str(booking?['ref'] ?? widget.ref)});
    if (!mounted) return;
    setState(() => busy = false);
    if (res.ok) {
      setState(() => payLater = true);
      final b = booking;
      if (b != null) {
        b['payment'] = 'after';
        Store.instance.set(_lastBookingKey, b);
      }
    } else {
      toast(context, res.error);
    }
  }

  String _niceDate(String value) {
    final d = DateTime.tryParse(value);
    if (d == null) return value;
    return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final ref = str(b?['ref']).isNotEmpty ? str(b!['ref']) : widget.ref;
    final awaiting = widget.paymentFailed && !payLater;
    final online = _online && !payLater;
    final mobile = str(b?['mobile']);
    final street = [str(b?['houseNo']), str(b?['area'])].where((s) => s.isNotEmpty).join(', ');
    final town = [str(b?['city']), str(b?['state'])].where((s) => s.isNotEmpty).join(', ');
    final services = mapsOf(b?['services']);
    final paymentUrl = str(b?['paymentUrl']);

    return DFScaffold(
      title: 'Booking',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Section(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: (awaiting ? DF.warning : DF.primary600).withValues(alpha: 0.1)),
                    alignment: Alignment.center,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: awaiting ? DF.warning : DF.primary600),
                      child: Icon(awaiting ? Icons.account_balance_wallet_outlined : Icons.check, size: 24, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(awaiting ? 'Payment not completed' : 'Booking confirmed',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DF.ink900)),
                const SizedBox(height: 4),
                Text(
                  awaiting
                      ? 'Your visit is held with our service team — only the online payment did not go through.'
                      : mobile.isNotEmpty
                          ? 'Our team will call you on +91 $mobile to confirm the time.'
                          : 'Our team will call you to confirm the time.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: DF.ink400, height: 1.45),
                ),
                if (ref.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Booking $ref', bg: DF.canvas, fg: DF.ink700),
                      _pill(awaiting || online ? 'Payment pending' : 'Pay after the visit', bg: DF.primary50, fg: DF.primary800),
                    ],
                  ),
                ],
                if (b?['duplicate'] == true) ...[
                  const SizedBox(height: 10),
                  const Text('This number already has a visit open with our service team — it stands, and this booking is added to it.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: DF.ink400)),
                ],
                if ((awaiting || online) && b != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: DF.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      back || awaiting
                          ? 'Nothing has been charged if the payment did not go through. You can pay for the visit now, or let the technician take cash, UPI or card after the work is done.'
                          : 'The payment page opened in your browser. If it did not go through, you can pay for the visit now, or let the technician take cash, UPI or card after the work is done.',
                      style: const TextStyle(fontSize: 12.5, height: 1.5, color: DF.ink500),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (paymentUrl.isNotEmpty) ...[
                    PrimaryButton('Pay now',
                        icon: Icons.verified_user_outlined, height: 46, onPressed: () => Native.open(paymentUrl, context: context)),
                    const SizedBox(height: 8),
                  ],
                  OutlineButton('Pay after the visit instead',
                      icon: Icons.account_balance_wallet_outlined,
                      height: 46,
                      color: DF.ink800,
                      borderColor: DF.lineStrong,
                      onPressed: busy ? null : _payLater),
                ],
                if (payLater) ...[
                  const SizedBox(height: 12),
                  const SuccessNote('Noted — the technician will take the payment after the visit.'),
                ],
              ],
            ),
          ),
          if (b != null) ...[
            _Section(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('What we are coming for', style: _heading),
                  const SizedBox(height: 4),
                  for (final s in services)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text.rich(TextSpan(
                              text: str(s['name']),
                              style: const TextStyle(fontSize: 14, color: DF.ink900),
                              children: [
                                if (toInt(s['qty'], 1) > 1)
                                  TextSpan(text: ' × ${toInt(s['qty'])}', style: const TextStyle(color: DF.ink400)),
                              ],
                            )),
                          ),
                          Text(formatPrice(toNum(s['price']) * toInt(s['qty'], 1)),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink700)),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DF.ink900)),
                        const Spacer(),
                        Text(formatPrice(toNum(b['amount'])),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.primary800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _line(Icons.event_available_outlined, 'Visit', [
                    [_niceDate(str(b['date'])), str(b['slot'])].where((s) => s.isNotEmpty).join('  ·  ').isNotEmpty
                        ? [_niceDate(str(b['date'])), str(b['slot'])].where((s) => s.isNotEmpty).join('  ·  ')
                        : 'Our team will confirm a slot',
                  ]),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _line(Icons.location_on_outlined, 'Address', [
                    if (street.isNotEmpty) street,
                    if (town.isNotEmpty) town,
                    if (str(b['pincode']).isNotEmpty) str(b['pincode']),
                  ]),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _line(Icons.account_balance_wallet_outlined, 'Payment', [
                    awaiting || online
                        ? 'Not paid yet — pay now, or the technician takes it after the visit'
                        : 'Pay the technician after the visit — cash, UPI or card',
                  ]),
                ],
              ),
            ),
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What happens next', style: _heading),
                  const SizedBox(height: 10),
                  for (final (i, (icon, title, note)) in _next.indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == _next.length - 1 ? 0 : 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                            child: Icon(icon, size: 15, color: DF.primary700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}. $title',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                                Text(note, style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton('Back to home', height: 48, onPressed: () => AppTabs.goHome(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlineButton('Book another',
                          height: 44,
                          fontSize: 14,
                          color: DF.ink700,
                          borderColor: DF.lineStrong,
                          onPressed: () =>
                              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ServicesScreen()))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlineButton('Call us',
                          icon: Icons.phone_outlined,
                          height: 44,
                          fontSize: 14,
                          color: DF.ink700,
                          borderColor: DF.lineStrong,
                          onPressed: () => Native.call()),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Need to change something? Call +91-9311587716 and quote your booking number.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: DF.ink400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {required Color bg, required Color fg, Color? border}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
      );

  Widget _line(IconData icon, String label, List<String> lines) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 17, color: DF.primary700)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: const TextStyle(fontSize: 12.5, letterSpacing: 0.5, color: DF.ink400)),
                  const SizedBox(height: 2),
                  for (final (i, l) in lines.indexed)
                    Text(l,
                        style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: label == 'Address' && i > 0 && l == str(booking?['pincode']) ? DF.ink500 : DF.ink900)),
                ],
              ),
            ),
          ],
        ),
      );
}
