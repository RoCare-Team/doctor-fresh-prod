import 'dart:async';

import 'package:flutter/material.dart';

import '../app_tabs.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/product_card.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

/// A full-width white block on the grey canvas (as in product_screen.dart).
class _Section extends StatelessWidget {
  const _Section({required this.child, this.top = 8, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final Widget child;
  final double top;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: top),
        color: Colors.white,
        padding: padding,
        child: child,
      );
}

/// A compact block heading with an optional muted note or action on the right.
class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.note, this.action});
  final String title;
  final String? note;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900))),
          if (note != null) Text(note!, style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
          if (action != null)
            GestureDetector(
              onTap: action!.$2,
              child: Text(action!.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DF.primary700)),
            ),
        ],
      ),
    );
  }
}

/* ==================================================================== auth */

/// Sign in and registration on the site's mobile + OTP flow
/// (components/forms/AuthForm.jsx, app/(shop)/login and registration).
///
/// Once signed in it returns `true` to whoever opened it when
/// [returnOnSuccess] is set (the checkout's sign-in prompt), otherwise it
/// opens the profile.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, this.register = false, this.returnOnSuccess = false});
  final bool register;
  final bool returnOnSuccess;

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: register ? 'Create account' : 'Sign in',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _AuthForm(
            register: register,
            onSignedIn: () {
              if (returnOnSuccess) {
                Navigator.pop(context, true);
              } else {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// The sign-in form, also shown in place of the profile when signed out.
class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.register, required this.onSignedIn});
  final bool register;
  final VoidCallback onSignedIn;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  late bool isRegister = widget.register;
  String step = 'details'; // details | code
  bool busy = false;
  String error = '';
  int seconds = 0;
  Timer? _timer;
  String sentTo = '';

  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final otp = TextEditingController();

  String get mode => isRegister ? 'register' : 'login';

  @override
  void dispose() {
    _timer?.cancel();
    name.dispose();
    email.dispose();
    mobile.dispose();
    otp.dispose();
    super.dispose();
  }

  /// Resend countdown — the API allows one code per minute per number.
  void _startCountdown() {
    _timer?.cancel();
    setState(() => seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => seconds--);
      if (seconds <= 0) t.cancel();
    });
  }

  Future<void> _requestCode() async {
    // What the site's `required` / pattern attributes check before sending.
    if (isRegister && name.text.trim().isEmpty) return setState(() => error = 'Please enter your name.');
    if (isRegister && !emailPattern.hasMatch(email.text.trim())) return setState(() => error = 'Please enter a valid email.');
    if (!RegExp(r'^\d{10}$').hasMatch(mobile.text.trim())) return setState(() => error = 'Please enter your 10 digit mobile number.');

    setState(() {
      busy = true;
      error = '';
    });
    final res = await Api.instance.post('/api/auth/request-otp', {
      'name': name.text.trim(),
      'email': email.text.trim(),
      'mobile': mobile.text.trim(),
      'mode': mode,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) return setState(() => error = res.error);
    sentTo = str(res.map['mobile']).isNotEmpty ? str(res.map['mobile']) : mobile.text.trim();
    otp.clear();
    setState(() => step = 'code');
    _startCountdown();
  }

  Future<void> _verify() async {
    if (otp.text.trim().isEmpty) return setState(() => error = 'Please enter the code.');
    setState(() {
      busy = true;
      error = '';
    });
    final res = await Api.instance.post('/api/auth/verify-otp', {
      'name': name.text.trim(),
      'email': email.text.trim(),
      'mobile': sentTo,
      'otp': otp.text.trim(),
      'mode': mode,
    });
    if (!mounted) return;
    if (!res.ok || res.map['user'] is! Map) {
      return setState(() {
        busy = false;
        error = res.error;
      });
    }
    await AppScope.read(context).signedInAs(res.map['user'] as Map);
    if (!mounted) return;
    widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final code = step == 'code';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // brand / illustration header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            children: [
              Image.asset('assets/images/logo2-trimmed.png', height: 28),
              const SizedBox(height: 18),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                child: Icon(code ? Icons.sms_outlined : Icons.phone_iphone, size: 34, color: DF.primary600),
              ),
            ],
          ),
        ),
        _Section(
          top: 0,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [if (code) ..._code() else ..._details()],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(isRegister ? 'Already have an account? ' : 'New to Doctor Fresh? ',
                  style: const TextStyle(fontSize: 13.5, color: DF.ink400)),
              GestureDetector(
                onTap: () => setState(() {
                  isRegister = !isRegister;
                  step = 'details';
                  error = '';
                }),
                child: Text(isRegister ? 'Sign in' : 'Create an account',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DF.primary700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _details() => [
        Text(isRegister ? 'Create your account' : 'Sign in to your account',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
        const SizedBox(height: 4),
        Text(
          isRegister ? 'Track orders, service requests and AMC plans in one place.' : 'We will send a one-time code to your mobile number.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: DF.ink400, height: 1.45),
        ),
        const SizedBox(height: 18),
        if (isRegister) ...[
          DFField(label: 'Full name', controller: name, required: true, hint: 'Your name', keyboard: TextInputType.name, maxLength: 100),
          DFField(label: 'Email', controller: email, required: true, hint: 'you@example.com', keyboard: TextInputType.emailAddress),
        ],
        DFField(
          label: 'Mobile number',
          controller: mobile,
          required: true,
          hint: '10 digit mobile number',
          keyboard: TextInputType.phone,
          maxLength: 10,
          digitsOnly: true,
        ),
        if (error.isNotEmpty) ErrorNote(error),
        const SizedBox(height: 4),
        PrimaryButton(busy ? 'Sending code…' : 'Send OTP', onPressed: busy ? null : _requestCode),
      ];

  List<Widget> _code() => [
        const Text('Enter the code',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: 'We sent a code to ',
            style: const TextStyle(fontSize: 13, color: DF.ink400, height: 1.45),
            children: [
              TextSpan(text: '+91 $sentTo', style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink700)),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              step = 'details';
              error = '';
            }),
            style: TextButton.styleFrom(foregroundColor: DF.primary700, visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Change number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        const Text.rich(TextSpan(
          text: 'One-time code',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700),
          children: [TextSpan(text: ' *', style: TextStyle(color: DF.danger))],
        )),
        const SizedBox(height: 6),
        TextField(
          controller: otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          onSubmitted: (_) => _verify(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: DF.ink900, letterSpacing: 6.8),
          decoration: const InputDecoration(hintText: 'Enter OTP', hintStyle: TextStyle(letterSpacing: 2, color: DF.ink300)),
        ),
        const SizedBox(height: 14),
        if (error.isNotEmpty) ErrorNote(error),
        PrimaryButton(busy ? 'Verifying…' : (isRegister ? 'Create account' : 'Sign in'), onPressed: busy ? null : _verify),
        const SizedBox(height: 4),
        TextButton(
          onPressed: seconds > 0 || busy ? null : _requestCode,
          style: TextButton.styleFrom(foregroundColor: DF.primary700, disabledForegroundColor: DF.ink300),
          child: Text(seconds > 0 ? 'Resend code in ${seconds}s' : 'Resend code', style: const TextStyle(fontSize: 13.5)),
        ),
      ];
}

/* ================================================================= profile */

const _delivery = {
  'pending': ('Being processed', 'wait'),
  'processing': ('Being processed', 'wait'),
  'on_delivery': ('Shipped', 'go'),
  'shipped': ('Shipped', 'go'),
  'delivered': ('Delivered', 'done'),
  'order cancelled': ('Cancelled', 'off'),
  'cancelled': ('Cancelled', 'off'),
};

(String, String) _status(dynamic delivery) => _delivery[str(delivery)] ?? (str(delivery), 'wait');

DateTime? _time(dynamic v) {
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v) ?? (int.tryParse(v) != null ? DateTime.fromMillisecondsSinceEpoch(int.parse(v)) : null);
  }
  return null;
}

String _initials(String name, String mobile) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  if (parts.length == 1) return parts[0].substring(0, parts[0].length < 2 ? parts[0].length : 2).toUpperCase();
  return mobile.length >= 2 ? mobile.substring(mobile.length - 2) : 'DF';
}

String _capitalize(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

const _tabs = [
  ('Profile', Icons.account_circle_outlined),
  ('Order history', Icons.inventory_2_outlined),
  ('Wishlist', Icons.favorite_border),
  ('Edit profile', Icons.edit_outlined),
];

/// The account (app/(shop)/profile/page.jsx with components/account/*):
/// the identity card and tab strip of the phone layout, then the Profile,
/// Order history, Wishlist and Edit profile panels.
/// Data: GET /api/mobile/orders and GET /api/account.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late int tab = widget.initialTab.clamp(0, 3);
  List<Map<String, dynamic>> orders = [];
  Map<String, dynamic> profile = {};
  bool loaded = false;
  String? error;
  int? _loadedFor;

  // wishlist
  List<Product>? saved;
  bool savedLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AppScope.of(context).user;
    if (user != null && _loadedFor != user.id) {
      _loadedFor = user.id;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => error = null);
    final results = await Future.wait([Api.instance.get('/api/mobile/orders'), Api.instance.get('/api/account')]);
    if (!mounted) return;
    final res = results[0];
    final account = results[1];
    if (res.needsSignIn) {
      await AppScope.read(context).refreshSession();
      return;
    }
    setState(() {
      if (!res.ok) {
        error = res.error;
        return;
      }
      loaded = true;
      orders = mapsOf(res.map['orders']);
      final p = account.ok ? account.map['profile'] : res.map['profile'];
      profile = p is Map ? Map<String, dynamic>.from(p) : {};
    });
    if (tab == 2) _loadSaved();
  }

  Future<void> _loadSaved() async {
    final ids = AppScope.read(context).wishlist;
    if (ids.isEmpty) {
      setState(() => saved = []);
      return;
    }
    setState(() => savedLoading = true);
    final res = await Api.instance.get('/api/mobile/products', query: {'ids': ids.join(',')});
    if (!mounted) return;
    setState(() {
      savedLoading = false;
      saved = mapsOf(res.map['products']).map(Product.fromJson).toList();
    });
  }

  void _setTab(int i) {
    setState(() => tab = i);
    if (i == 2) _loadSaved();
  }

  Future<void> _signOut() async {
    await AppScope.read(context).signOut();
    if (mounted) AppTabs.goHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return DFScaffold(
      title: 'My account',
      body: !state.signedIn
          ? ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [_AuthForm(register: false, onSignedIn: () {})],
            )
          : !loaded
              ? LoadState(error: error, onRetry: _load)
              : RefreshIndicator(
                  color: DF.primary600,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _header(state),
                      _tabStrip(state),
                      ...switch (tab) {
                        1 => _ordersPanel(),
                        2 => _wishlistPanel(state),
                        3 => _editPanel(),
                        _ => _profilePanel(state),
                      },
                    ],
                  ),
                ),
    );
  }

  Widget _header(AppState state) {
    final nameText = str(profile['name']).isNotEmpty ? str(profile['name']) : (state.user?.name ?? '');
    final mobile = str(profile['mobile']).isNotEmpty ? str(profile['mobile']) : (state.user?.mobile ?? '');
    return _Section(
      top: 0,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: DF.primary600, shape: BoxShape.circle),
            child:
                Text(_initials(nameText, mobile), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nameText.isEmpty ? 'Your account' : _capitalize(nameText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                Text('+91 $mobile', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: DF.ink400)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _signOut,
            style: TextButton.styleFrom(foregroundColor: DF.danger, visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// The tabs as a horizontal chip strip in a white bar.
  Widget _tabStrip(AppState state) {
    final counts = {1: orders.length, 2: state.wishlist.length};
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (final (i, (label, icon)) in _tabs.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              InkWell(
                onTap: () => _setTab(i),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: tab == i ? DF.primary600 : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tab == i ? DF.primary600 : DF.lineStrong),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 15, color: tab == i ? Colors.white : DF.ink400),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tab == i ? Colors.white : DF.ink700)),
                      if ((counts[i] ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: tab == i ? Colors.white.withValues(alpha: 0.25) : DF.canvas,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('${counts[i]}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tab == i ? Colors.white : DF.ink500)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /* ------------------------------------------------------------- profile */

  List<Widget> _profilePanel(AppState state) {
    final now = DateTime.now();
    num since(int days) => orders.where((o) {
          final t = _time(o['placedAt']);
          return t != null && now.difference(t).inMilliseconds <= days * 86400000;
        }).fold<num>(0, (s, o) => s + toNum(o['total']));
    final total = orders.fold<num>(0, (s, o) => s + toNum(o['total']));
    final address = ['address1', 'address2', 'city', 'state', 'zip'].map((k) => str(profile[k])).where((s) => s.isNotEmpty).join(', ');
    final memberSince = str(profile['memberSince']);
    final lastLogin = str(profile['lastLogin']);
    final recent = orders.take(3).toList();

    return [
      _Section(
        child: Column(
          children: [
            _Metric(icon: Icons.account_balance_wallet_outlined, label: 'Total purchase', value: formatPrice(total), accent: true),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(icon: Icons.inventory_2_outlined, label: 'Orders placed', value: '${orders.length}')),
              const SizedBox(width: 8),
              Expanded(child: _Metric(icon: Icons.favorite_border, label: 'Saved products', value: '${state.wishlist.length}')),
            ]),
          ],
        ),
      ),
      if (orders.isEmpty)
        const _Empty(icon: Icons.inventory_2_outlined, title: 'No orders yet', body: 'Everything you buy will show here, with its invoice.')
      else
        _Section(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading('Recent orders', action: ('View all', () => _setTab(1))),
              for (final (i, o) in recent.indexed) ...[
                if (i > 0) const Divider(height: 1),
                _OrderRow(order: o),
              ],
            ],
          ),
        ),
      _Section(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading('Contact details', action: ('Edit', () => _setTab(3))),
            _detail(Icons.mail_outline, 'Email', str(profile['email'])),
            _detail(Icons.phone_outlined, 'Contact no', str(profile['mobile']).isEmpty ? '' : '+91 ${profile['mobile']}'),
            _detail(Icons.location_on_outlined, 'Address', address),
            _detail(Icons.public, 'Country', str(profile['country']), last: true),
          ],
        ),
      ),
      _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Heading('Purchase summary'),
            _InfoRow('Last 7 days', formatPrice(since(7))),
            _InfoRow('Last 30 days', formatPrice(since(30))),
            _InfoRow('All time', formatPrice(total), strong: true, last: true),
          ],
        ),
      ),
      _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Heading('Account'),
            _InfoRow('Member since', memberSince.isNotEmpty ? formatDate(profile['memberSince']) : '—'),
            _InfoRow('Last login', lastLogin.isNotEmpty ? formatDate(profile['lastLogin']) : '—', last: true),
          ],
        ),
      ),
    ];
  }

  Widget _detail(IconData icon, String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: DF.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: DF.primary600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                // An empty detail is an invitation, not a dead end.
                if (value.isNotEmpty)
                  Text(value, style: const TextStyle(fontSize: 14, color: DF.ink900))
                else
                  GestureDetector(
                    onTap: () => _setTab(3),
                    child: Text('+ Add ${label.toLowerCase()}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.primary700)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* -------------------------------------------------------------- orders */

  List<Widget> _ordersPanel() {
    if (orders.isEmpty) {
      return const [
        _Empty(icon: Icons.inventory_2_outlined, title: 'No orders yet', body: 'Everything you buy will show here, with its invoice.'),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text('${orders.length} order${orders.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: DF.ink400)),
      ),
      for (final o in orders) _OrderCard(order: o, onChanged: _load),
      _OrderTrace(orders: orders),
    ];
  }

  /* ------------------------------------------------------------ wishlist */

  List<Widget> _wishlistPanel(AppState state) {
    final list = (saved ?? const <Product>[]).where((p) => state.saved(p.id)).toList();
    if (saved == null || savedLoading) return const [Padding(padding: EdgeInsets.only(top: 8), child: LoadState())];
    if (list.isEmpty) {
      return const [
        _Empty(icon: Icons.favorite_border, title: 'Nothing saved yet', body: 'Tap the heart on any product to keep it here for later.'),
      ];
    }
    return [
      _Section(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: _Heading('Your wishlist', note: '${state.wishlist.length} saved'),
            ),
            for (final (i, p) in list.indexed) ...[
              if (i > 0) const Divider(height: 1),
              ProductRow(
                product: p,
                trailing: IconButton(
                  tooltip: 'Remove',
                  onPressed: () => state.toggleWishlist(p.id),
                  icon: const Icon(Icons.favorite, color: DF.danger, size: 22),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  /* ---------------------------------------------------------------- edit */

  List<Widget> _editPanel() => [
        _ProfileForm(key: ValueKey(profile['id']), profile: profile, onSaved: _load),
      ];
}

/// A compact metric tile on a light canvas fill.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value, this.accent = false});
  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: accent ? DF.primary50 : DF.canvas, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: accent ? DF.primary600 : Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: accent ? Colors.white : DF.primary700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: DF.ink400)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.strong = false, this.last = false});
  final String label;
  final String value;
  final bool strong;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: DF.line))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: DF.ink500))),
          Text(value,
              style: TextStyle(
                fontSize: strong ? 15 : 14,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                color: strong ? DF.primary700 : DF.ink900,
              )),
        ],
      ),
    );
  }
}

/// A status chip: done (green), go (blue), wait (grey), off (red).
class _Pill extends StatelessWidget {
  const _Pill(this.status);
  final (String, String) status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.$2) {
      'done' => (const Color(0x1A0A7A50), DF.success),
      'go' => (DF.primary50, DF.primary800),
      'off' => (const Color(0x1AD92D20), DF.danger),
      _ => (DF.canvas, DF.ink500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Section(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: DF.ink300),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: DF.ink400)),
          const SizedBox(height: 18),
          SizedBox(
              width: 220, child: PrimaryButton('Browse products', height: 44, onPressed: () => AppRouter.open(context, '/all-category'))),
        ],
      ),
    );
  }
}

/// A compact tappable order row: code, date and items, status chip, total.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return InkWell(
      onTap: () => AppRouter.push(context, OrderScreen(ref: str(o['id']))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, size: 18, color: DF.primary700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(o['code']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDate(o['placedAt'])} · ${toInt(o['itemCount'])} item${toInt(o['itemCount']) == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12.5, color: DF.ink400),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(toNum(o['total'])), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DF.ink900)),
                const SizedBox(height: 4),
                _Pill(_status(o['delivery'])),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: DF.ink300),
          ],
        ),
      ),
    );
  }
}

/// One order in the history: code, date, status chips, items, total and actions.
class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.order, required this.onChanged});
  final Map<String, dynamic> order;
  final Future<void> Function() onChanged;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool busy = false;

  Future<void> _invoice() async {
    final o = widget.order;
    setState(() => busy = true);
    final err = await Native.downloadAndOpen('/api/orders/invoice/${o['id']}', 'invoice-${o['code']}.pdf');
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) toast(context, err);
  }

  Future<void> _cancel() async {
    final o = widget.order;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('Order ${o['code']} will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: DF.danger),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    final res = await Api.instance.post('/api/orders/cancel', {'saleId': toInt(o['id'])});
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) return toast(context, res.error);
    toast(context, 'Order cancelled');
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final items = mapsOf(o['items']);
    final status = _status(o['delivery']);
    final cancellable = ['pending', 'processing'].contains(str(o['delivery']));
    void open() => AppRouter.push(context, OrderScreen(ref: str(o['id'])));

    return _Section(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(TextSpan(
                          text: str(o['code']),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DF.ink900),
                          children: [
                            TextSpan(
                                text: '  ${formatDate(o['placedAt'])}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: DF.ink400)),
                          ],
                        )),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: DF.ink300),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Pill(status),
                    _Pill(o['paid'] == true ? ('Paid', 'done') : ('Payment due', 'off')),
                  ]),
                  const SizedBox(height: 8),
                  for (final item in items.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                          child: Text(str(item['name']),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: DF.ink700)),
                        ),
                        const SizedBox(width: 12),
                        Text('× ${toInt(item['qty'], 1)}', style: const TextStyle(fontSize: 13, color: DF.ink400)),
                      ]),
                    ),
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('and ${items.length - 3} more', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(TextSpan(
                    text: 'Total  ',
                    style: const TextStyle(fontSize: 12.5, color: DF.ink400),
                    children: [
                      TextSpan(
                          text: formatPrice(toNum(o['total'])),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)),
                    ],
                  )),
                ),
                if (cancellable)
                  TextButton(
                    onPressed: busy ? null : _cancel,
                    style: TextButton.styleFrom(foregroundColor: DF.danger, visualDensity: VisualDensity.compact),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                TextButton.icon(
                  onPressed: busy ? null : _invoice,
                  style: TextButton.styleFrom(foregroundColor: DF.primary700, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.download, size: 15),
                  label: const Text('Invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Trace my order" (components/account/OrderTrace.jsx): matched against the
/// customer's own orders.
class _OrderTrace extends StatefulWidget {
  const _OrderTrace({required this.orders});
  final List<Map<String, dynamic>> orders;

  @override
  State<_OrderTrace> createState() => _OrderTraceState();
}

class _OrderTraceState extends State<_OrderTrace> {
  final code = TextEditingController();
  String error = '';

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void _submit() {
    final wanted = code.text.trim().toLowerCase();
    if (wanted.isEmpty) return;
    final found = widget.orders.where((o) => str(o['code']).toLowerCase() == wanted || str(o['id']) == wanted).firstOrNull;
    if (found == null) return setState(() => error = 'No order of yours has that code.');
    AppRouter.push(context, OrderScreen(ref: str(found['id'])));
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Trace my order'),
          const Text('Enter the sale code from your order.', style: TextStyle(fontSize: 13, color: DF.ink400)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: code,
                    onChanged: (_) => setState(() => error = ''),
                    onSubmitted: (_) => _submit(),
                    style: const TextStyle(fontSize: 14, color: DF.ink900),
                    decoration:
                        const InputDecoration(hintText: 'Sale code', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PrimaryButton('Trace', icon: Icons.search, height: 40, radius: 8, fontSize: 14, onPressed: _submit),
            ],
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 13, color: DF.danger)),
          ],
        ],
      ),
    );
  }
}

/// Edit profile (components/account/ProfileForm.jsx) → PATCH /api/account.
class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.profile, required this.onSaved});
  final Map<String, dynamic> profile;
  final Future<void> Function() onSaved;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final Map<String, TextEditingController> c = {
    'username': TextEditingController(text: str(widget.profile['firstName'])),
    'surname': TextEditingController(text: str(widget.profile['lastName'])),
    'email': TextEditingController(text: str(widget.profile['email'])),
    'address1': TextEditingController(text: str(widget.profile['address1'])),
    'address2': TextEditingController(text: str(widget.profile['address2'])),
    'city': TextEditingController(text: str(widget.profile['city'])),
    'state': TextEditingController(text: str(widget.profile['state'])),
    'zip': TextEditingController(text: str(widget.profile['zip'])),
    'country': TextEditingController(text: str(widget.profile['country']).isEmpty ? 'India' : str(widget.profile['country'])),
  };
  String status = 'idle'; // idle | saving | done | error
  String error = '';

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (c['username']!.text.trim().isEmpty) {
      return setState(() {
        status = 'error';
        error = 'Please enter your first name.';
      });
    }
    setState(() {
      status = 'saving';
      error = '';
    });
    final res = await Api.instance.patch('/api/account', {for (final e in c.entries) e.key: e.value.text.trim()});
    if (!mounted) return;
    if (!res.ok) {
      return setState(() {
        status = 'error';
        error = res.map['error'] is String || res.networkError ? res.error : 'Could not save your details.';
      });
    }
    setState(() => status = 'done');
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Edit profile', note: 'Used for delivery and invoices'),
          const SizedBox(height: 6),
          DFField(label: 'First name', controller: c['username']!, required: true, maxLength: 100, keyboard: TextInputType.name),
          DFField(label: 'Last name', controller: c['surname']!, maxLength: 100, keyboard: TextInputType.name),
          DFField(label: 'Email', controller: c['email']!, hint: 'you@example.com', keyboard: TextInputType.emailAddress),
          const Text('Mobile number', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700)),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Text('+91 ${widget.profile['mobile'] ?? ''}', style: const TextStyle(fontSize: 14, color: DF.ink500)),
              const Spacer(),
              const Text('used to sign in', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
            ]),
          ),
          const SizedBox(height: 12),
          DFField(label: 'Address line 1', controller: c['address1']!, hint: 'House / building, street'),
          DFField(label: 'Address line 2', controller: c['address2']!, hint: 'Area, landmark'),
          DFField(label: 'City', controller: c['city']!),
          DFField(label: 'State', controller: c['state']!),
          DFField(label: 'Pin code', controller: c['zip']!, keyboard: TextInputType.number, maxLength: 6, digitsOnly: true),
          DFField(label: 'Country', controller: c['country']!),
          if (status == 'error') ErrorNote(error),
          if (status == 'done')
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(Icons.check_circle_outline, size: 16, color: DF.success),
                SizedBox(width: 6),
                Text('Saved', style: TextStyle(fontSize: 13.5, color: DF.success)),
              ]),
            ),
          const SizedBox(height: 4),
          PrimaryButton(status == 'saving' ? 'Saving…' : 'Save details', onPressed: status == 'saving' ? null : _save),
        ],
      ),
    );
  }
}

/* =================================================================== order */

const _paymentLabel = {
  'cash_on_delivery': 'Cash on delivery',
  'easebuzz': 'Paid online',
  'sslcommerz': 'Paid online (SSLCommerz)',
  'paytm': 'Paytm',
  'ccavenue': 'CCAvenue',
  'pum': 'PayUmoney',
  'stripe': 'Card',
  'paypal': 'PayPal',
};

/// The order confirmation (app/(shop)/order/[ref]/page.jsx) from
/// GET /api/mobile/orders?id=<ref>. [ref] is a sale id, or a guest id.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.ref, this.justPlaced = false});
  final String ref;
  final bool justPlaced;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Map<String, dynamic>? order;
  String? error;
  bool needsSignIn = false;
  bool downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      needsSignIn = false;
    });
    final res = await Api.instance.get('/api/mobile/orders', query: {'id': widget.ref});
    if (!mounted) return;
    setState(() {
      if (res.ok && res.map['order'] is Map) {
        order = Map<String, dynamic>.from(res.map['order']);
      } else {
        needsSignIn = res.needsSignIn;
        error = res.error;
      }
    });
  }

  Future<void> _invoice() async {
    final o = order!;
    final guestId = str(o['guestId']);
    final ref = guestId.isNotEmpty ? guestId : str(o['id']);
    setState(() => downloading = true);
    final err = await Native.downloadAndOpen('/api/orders/invoice/${Uri.encodeComponent(ref)}', 'invoice-${o['code']}.pdf');
    if (!mounted) return;
    setState(() => downloading = false);
    if (err != null) toast(context, err);
  }

  void _home() => AppTabs.goHome(context);

  @override
  Widget build(BuildContext context) {
    // A just-placed order goes back to the shop, not to the emptied checkout.
    return PopScope(
      canPop: !widget.justPlaced,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: DFScaffold(title: 'Order details', body: _body()),
    );
  }

  Widget _body() {
    if (order == null) {
      if (needsSignIn) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Section(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                      child: const Icon(Icons.lock_outline, size: 40, color: DF.primary600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Sign in to see this order',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                  const SizedBox(height: 18),
                  PrimaryButton('Sign in', onPressed: () async {
                    final ok = await AppRouter.push<bool>(context, const AuthScreen(returnOnSuccess: true));
                    if (ok == true) _load();
                  }),
                ],
              ),
            ),
          ],
        );
      }
      return LoadState(error: error, onRetry: _load);
    }

    final o = order!;
    final address = (o['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totals = (o['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final items = mapsOf(o['items']);
    final payment = _paymentLabel[str(o['paymentType'])] ?? _paymentLabel[str(address['payment'])] ?? 'Cash on delivery';

    Widget total(String label, String key, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: strong
                        ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)
                        : const TextStyle(fontSize: 14, color: DF.ink500))),
            Text(formatPrice(toNum(totals[key])),
                style: strong
                    ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)
                    : const TextStyle(fontSize: 14, color: DF.ink700)),
          ]),
        );

    Widget block(IconData icon, String title, String text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: DF.primary700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                  Text(text, style: const TextStyle(fontSize: 14, color: DF.ink900, height: 1.4)),
                ],
              ),
            ),
          ],
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // status
        _Section(
          top: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0x1A0A7A50), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, size: 24, color: DF.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order placed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(
                      text: 'Order ',
                      style: const TextStyle(fontSize: 13, color: DF.ink500, height: 1.45),
                      children: [
                        TextSpan(text: str(o['code']), style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink900)),
                        TextSpan(text: ' — our team will call you on ${str(address['mobile'])} to confirm delivery.'),
                      ],
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),

        // items
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading('Items', note: '${items.length}'),
              for (final (n, i) in items.indexed) ...[
                if (n > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(i['name']), style: const TextStyle(fontSize: 14, color: DF.ink900, height: 1.35)),
                            const SizedBox(height: 2),
                            Text('Qty ${toInt(i['qty'], 1)}', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(formatPrice(toNum(i['subtotal'])),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // totals
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Heading('Price details'),
              total('Subtotal', 'subtotal'),
              total('GST', 'tax'),
              total('Shipping', 'shipping'),
              const Divider(height: 14),
              total('Total', 'grandTotal', strong: true),
            ],
          ),
        ),

        // delivery and payment
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              block(Icons.location_on_outlined, 'Delivering to',
                  '${str(address['name'])}, ${str(address['house_no'])} ${str(address['area'])}, ${str(address['city'])} ${str(address['c_pincode'])}'),
              const SizedBox(height: 12),
              block(Icons.payments_outlined, 'Payment', '$payment${o['paid'] == true ? ' — paid' : ''}'),
              if (str(o['guestId']).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: DF.ink400),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('Keep this link to check your order later — you ordered as a guest.',
                          style: TextStyle(fontSize: 12.5, color: DF.ink400)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // actions
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton('Continue shopping', onPressed: _home),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlineButton(
                      downloading ? 'Downloading…' : 'Invoice',
                      icon: Icons.download,
                      height: 44,
                      fontSize: 14,
                      color: DF.primary800,
                      borderColor: DF.primary200,
                      fill: DF.primary50,
                      onPressed: downloading ? null : _invoice,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlineButton('Call us', icon: Icons.call_outlined, height: 44, fontSize: 14, onPressed: () => Native.call()),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Center(
            child: GestureDetector(
              onTap: () => AppRouter.open(context, '/contact'),
              child: const Text.rich(TextSpan(
                text: 'Questions? Call ${Config.phone} or ',
                style: TextStyle(fontSize: 12.5, color: DF.ink400),
                children: [TextSpan(text: 'contact us', style: TextStyle(color: DF.primary700, fontWeight: FontWeight.w600))],
              )),
            ),
          ),
        ),
      ],
    );
  }
}
