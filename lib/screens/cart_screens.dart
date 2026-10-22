import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/forms.dart';
import '../widgets/net_image.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';
import 'account_screens.dart';
import 'product_screen.dart';

//// The shopping cart (app/(shop)/cart/page.jsx + components/cart/CartView.jsx).
/// The lines live in [AppState.cart], on the device, as the site keeps them
/// in localStorage.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _goToCheckout(BuildContext context) async {
    final state = AppScope.read(context);
    if (state.signedIn || await showSignInPrompt(context)) {
      if (context.mounted) AppRouter.push(context, const CheckoutScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.cart;
    final count = state.cartCount;

    return DFScaffold(
      title: 'My cart',
      bottomBar: items.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatPrice(state.subtotal),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.2)),
                      Text('$count item${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: DF.ink400, height: 1.3)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton('Proceed to checkout', height: 46, fontSize: 14.5, onPressed: () => _goToCheckout(context)),
                  ),
                ],
              ),
            ),
      body: items.isEmpty
          ? const _EmptyCart()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final (i, item) in items.indexed) _CartLineCard(item: item, top: i == 0 ? 0 : 1),
                _Section(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => AppRouter.open(context, '/all-category'),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          Icon(Icons.add_shopping_cart, size: 18, color: DF.primary700),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Continue shopping',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.primary700)),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: DF.ink300),
                        ],
                      ),
                    ),
                  ),
                ),
                _Section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Price details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                      const SizedBox(height: 8),
                      _SummaryRow('Item total (MRP)', formatPrice(state.mrpTotal)),
                      if (state.savings > 0) _SummaryRow('Discount', '− ${formatPrice(state.savings)}', success: true),
                      const _SummaryRow('Shipping', 'Free', success: true),
                      const Divider(height: 14),
                      _SummaryRow('Subtotal', formatPrice(state.subtotal), strong: true),
                      if (state.savings > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(color: DF.saveBg, borderRadius: BorderRadius.circular(8)),
                          child: Text('You save ${formatPrice(state.savings)} on this order',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DF.save)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.build_outlined, size: 13, color: DF.ink400),
                      SizedBox(width: 6),
                      Text('Free installation included on water purifiers', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

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

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag_outlined, size: 48, color: DF.ink300),
            ),
            const SizedBox(height: 16),
            const Text('Your cart is empty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
            const SizedBox(height: 4),
            const Text(
              'Browse water purifiers, softeners and spare parts to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: DF.ink400, height: 1.45),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: PrimaryButton('Shop water purifiers', onPressed: () => AppRouter.open(context, '/category/water-purifier')),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => AppRouter.open(context, '/all-category'),
              style: TextButton.styleFrom(foregroundColor: DF.primary700),
              child: const Text('All categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cart line as a compact white row: image, name, price, the stepper,
/// the line total and a remove icon.
class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.item, this.top = 1});
  final CartLine item;
  final double top;

  void _open(BuildContext context) => AppRouter.push(context, ProductScreen(id: item.id, name: item.name));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return _Section(
      top: top,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _open(context),
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(10)),
              child: NetImage(Config.url(item.image)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _open(context),
                  child: Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DF.ink900, height: 1.35)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(formatPrice(item.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)),
                    if (item.mrp > item.price)
                      Text(formatPrice(item.mrp),
                          style: const TextStyle(fontSize: 12.5, color: DF.ink400, decoration: TextDecoration.lineThrough)),
                    if (item.unit.isNotEmpty) Text(item.unit, style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QtyStepper(
                      value: item.qty,
                      max: item.maxQty,
                      height: 32,
                      onChanged: (q) => state.setQty(item.id, q),
                    ),
                    const Spacer(),
                    Text(formatPrice(item.price * item.qty),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink700)),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => state.removeFromCart(item.id),
            icon: const Icon(Icons.delete_outline, size: 20, color: DF.ink400),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.success = false, this.strong = false});
  final String label;
  final String value;
  final bool success;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final labelStyle = strong
        ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)
        : const TextStyle(fontSize: 14, color: DF.ink500);
    final valueStyle = strong
        ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)
        : TextStyle(fontSize: 14, color: success ? DF.primary700 : DF.ink700);
    return Padding(
      padding: EdgeInsets.only(top: strong ? 4 : 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 12),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

/* ================================================================ checkout */

const _stepTitles = {1: 'Add delivery address', 2: 'Order summary', 3: 'Payment'};

/// Checkout in the site's three steps — address, order summary, payment
/// (app/(shop)/cart-checkout/page.jsx, components/cart/CheckoutView.jsx and
/// AddressStep.jsx). Every number comes from POST /api/checkout/quote; the
/// order is placed with POST /api/checkout.
///
/// An online payment opens Easebuzz in the browser (there is no WebView);
/// when the app comes back to the front the order is read again to see
/// whether it was paid.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();

  int step = 1;
  Map<String, dynamic>? quote;
  String payment = '';
  String? couponCode;
  String couponError = '';
  bool placing = false;
  String error = '';

  // The address confirmed on step 1, shown back on the later steps.
  Map<String, dynamic>? address;
  final f = {
    for (final k in ['name', 'mobile', 'email', 'house_no', 'area', 'near_by', 'city', 'state', 'c_pincode', 'message'])
      k: TextEditingController(),
  };
  final couponInput = TextEditingController();
  String addressType = 'Home';
  Map<String, String> errors = {};
  bool showMore = false;
  bool _prefillStarted = false;

  // pin code lookup
  String lookupStatus = 'idle'; // idle | loading | found | missing
  List<String> areas = [];
  String lookupCity = '';
  String lookupState = '';
  String _autoCity = '';
  String _autoState = '';
  String _lookupPin = '';

  // online payment
  int? pendingSale;
  String pendingRedirect = '';
  String payState = ''; // '' | waiting | checking | failed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requote());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (state.signedIn && !_prefillStarted) {
      _prefillStarted = true;
      _prefill(state);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    for (final c in f.values) {
      c.dispose();
    }
    couponInput.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && pendingSale != null && payState == 'waiting') {
      _checkPayment();
    }
  }

  List<Map<String, dynamic>> get _lines => AppScope.read(context).cart.map((c) => {'id': c.id, 'qty': c.qty}).toList();

  /// What the account already knows — the saved address, else the contact.
  /// Nothing the customer has typed is overwritten.
  Future<void> _prefill(AppState state) async {
    final res = await Api.instance.get('/api/account/addresses');
    if (!mounted || !res.ok) return;
    final saved = mapsOf(res.map['addresses']);
    final contact = (res.map['contact'] as Map?)?.cast<String, dynamic>() ?? const {};
    void fill(String key, dynamic value) {
      final v = str(value).trim();
      if (f[key]!.text.isEmpty && v.isNotEmpty) f[key]!.text = v;
    }

    if (saved.isNotEmpty) {
      final a = saved.first;
      for (final k in f.keys) {
        fill(k, k == 'mobile' ? normaliseMobile(str(a[k])) : a[k]);
      }
      final type = str(a['address_type']);
      if (type == 'Home' || type == 'Work') addressType = type;
      if (f['near_by']!.text.isNotEmpty || f['message']!.text.isNotEmpty) showMore = true;
    }
    fill('name', contact['name'] ?? state.user?.name);
    fill('mobile', normaliseMobile(str(contact['mobile'] ?? state.user?.mobile)));
    fill('email', contact['email']);
    setState(() {});
    if (f['c_pincode']!.text.isNotEmpty) _lookupPinCode();
  }

  /// Reprices the basket (and the coupon) on the server.
  Future<ApiResult> _quote(String? code) => Api.instance.post('/api/checkout/quote', {'items': _lines, 'coupon': code});

  Future<void> _requote() async {
    if (AppScope.read(context).cart.isEmpty) return;
    final res = await _quote(couponCode);
    if (!mounted) return;
    setState(() {
      quote = res.data is Map ? res.map : {'ok': false, 'error': res.error};
      if (res.ok && payment.isEmpty) {
        payment = str(mapsOf(res.map['paymentOptions']).where((p) => p['ready'] == true).firstOrNull?['id']);
      }
    });
  }

  Future<void> _applyCoupon() async {
    setState(() => couponError = '');
    final code = couponInput.text.trim();
    if (code.isEmpty) return;
    final res = await _quote(code);
    if (!mounted) return;
    if (!res.ok) {
      setState(() => couponError = res.map['error'] is String ? res.error : 'That coupon could not be applied.');
      return;
    }
    setState(() {
      couponCode = code;
      quote = res.map;
    });
  }

  /* ------------------------------------------------------------- address */

  void _onPinChanged(String pin) {
    _clearError('c_pincode');
    _lookupPinCode();
  }

  Future<void> _lookupPinCode() async {
    final pin = f['c_pincode']!.text;
    _lookupPin = pin;
    if (!pinPattern.hasMatch(pin)) {
      setState(() {
        lookupStatus = 'idle';
        areas = [];
      });
      return;
    }
    setState(() => lookupStatus = 'loading');
    final res = await Api.instance.get('/api/pincode/$pin');
    if (!mounted || _lookupPin != pin) return;
    if (!res.ok) {
      setState(() {
        lookupStatus = 'missing';
        areas = [];
      });
      return;
    }
    final city = str(res.map['city']);
    final st = str(res.map['state']);
    setState(() {
      lookupStatus = 'found';
      areas = ((res.map['areas'] as List?) ?? const []).map((e) => '$e').toList();
      lookupCity = city;
      lookupState = st;
      if (f['city']!.text.isEmpty || f['city']!.text == _autoCity) f['city']!.text = city;
      if (f['state']!.text.isEmpty || f['state']!.text == _autoState) f['state']!.text = st;
      _autoCity = city;
      _autoState = st;
      errors.remove('city');
      errors.remove('state');
    });
  }

  void _clearError(String key) {
    if (errors.containsKey(key)) setState(() => errors.remove(key));
  }

  Map<String, dynamic> get _draft => {
        for (final e in f.entries) e.key: e.value.text.trim(),
        'address_type': addressType,
      };

  /// The rules /api/checkout applies (validateAddress in CheckoutView.jsx).
  Map<String, String> _validate(Map<String, dynamic> a) {
    final e = <String, String>{};
    String t(String k) => str(a[k]).trim();
    if (t('name').length < 2) e['name'] = 'Enter the full name';
    if (!mobilePattern.hasMatch(normaliseMobile(t('mobile')))) e['mobile'] = 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^\d{6}$').hasMatch(t('c_pincode'))) e['c_pincode'] = 'Enter a 6-digit pin code';
    if (t('house_no').isEmpty) e['house_no'] = 'Enter your house or flat number';
    if (t('area').isEmpty) e['area'] = 'Enter your area or road';
    if (t('city').isEmpty) e['city'] = 'Enter your city';
    if (t('state').isEmpty) e['state'] = 'Enter your state';
    if (t('email').isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t('email'))) e['email'] = 'Enter a valid email';
    return e;
  }

  void _continueToSummary() {
    final a = _draft;
    final problems = _validate(a);
    if (problems.isNotEmpty) {
      setState(() {
        errors = problems;
        if (problems.containsKey('email')) showMore = true;
      });
      return;
    }
    setState(() {
      errors = {};
      address = a;
    });
    _goTo(2);
  }

  void _goTo(int next) {
    setState(() {
      error = '';
      step = next;
    });
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  /* --------------------------------------------------------------- order */

  Future<void> _placeOrder() async {
    setState(() {
      placing = true;
      error = '';
    });
    final res = await Api.instance.post('/api/checkout', {
      'address': address ?? _draft,
      'items': _lines,
      'coupon': couponCode,
      'payment': payment,
    });
    if (!mounted) return;

    if (res.needsSignIn) {
      setState(() => placing = false);
      await AppScope.read(context).refreshSession();
      if (mounted) await showSignInPrompt(context);
      return;
    }
    if (!res.ok) {
      setState(() {
        placing = false;
        error = res.map['error'] is String || res.networkError ? res.error : 'Could not place your order. Please try again.';
      });
      return;
    }

    final saleId = toInt(res.map['saleId']);
    final redirect = str(res.map['redirect']);
    if (redirect.isNotEmpty) {
      // Easebuzz takes over; the cart is cleared once the payment is confirmed.
      setState(() {
        placing = false;
        pendingSale = saleId;
        pendingRedirect = redirect;
        payState = 'waiting';
      });
      await Native.open(redirect, context: context);
      return;
    }

    _finish(saleId);
  }

  void _finish(int saleId) {
    AppScope.read(context).clearCart();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderScreen(ref: '$saleId', justPlaced: true)),
    );
  }

  Future<void> _checkPayment() async {
    final saleId = pendingSale;
    if (saleId == null) return;
    setState(() => payState = 'checking');
    final res = await Api.instance.get('/api/mobile/orders', query: {'id': saleId});
    if (!mounted) return;
    final order = res.map['order'];
    if (res.ok && order is Map && order['paid'] == true) {
      _finish(saleId);
      return;
    }
    setState(() => payState = 'failed');
  }

  /* ---------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return DFScaffold(
      title: 'Checkout',
      checkoutMode: true,
      showDock: false,
      bottomBar: _bottomBar(state),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: _content(state),
      ),
    );
  }

  /// The step's main action, pinned under the page with the grand total.
  Widget? _bottomBar(AppState state) {
    if (payState.isNotEmpty || state.cart.isEmpty || !state.sessionChecked || !state.signedIn) return null;
    final totals = quote?['totals'] as Map?;
    final Widget action = switch (step) {
      1 => _ArrowButton('Save and continue', onPressed: _continueToSummary),
      2 => _ArrowButton('Continue to payment', onPressed: () => _goTo(3)),
      _ => PrimaryButton(
          placing ? 'Placing order…' : 'Place order',
          height: 46,
          loading: placing,
          onPressed: totals == null || payment.isEmpty ? null : _placeOrder,
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(totals == null ? '—' : formatPrice(toNum(totals['grandTotal'])),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900, height: 1.2)),
              const Text('Grand total', style: TextStyle(fontSize: 12, color: DF.ink400, height: 1.3)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(child: action),
        ],
      ),
    );
  }

  List<Widget> _content(AppState state) {
    if (payState.isNotEmpty) return [_paymentPanel()];

    if (state.cart.isEmpty) {
      return [
        _Section(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              const _RoundIcon(Icons.shopping_bag_outlined),
              const SizedBox(height: 14),
              const Text('Nothing to check out', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
              const SizedBox(height: 4),
              const Text('Add a product to your cart first.', style: TextStyle(fontSize: 13, color: DF.ink400)),
              const SizedBox(height: 18),
              PrimaryButton('Browse products', onPressed: () => AppRouter.open(context, '/all-category')),
            ],
          ),
        ),
      ];
    }

    if (!state.sessionChecked) return [const LoadState()];
    if (!state.signedIn) return [_signInCard()];

    return [
      _topBar(),
      if (step == 1) _addressStep(),
      if (step == 2) ..._summaryStep(state),
      if (step == 3) ..._paymentStep(),
      _summaryCard(state),
      _secureNote(),
    ];
  }

  Widget _signInCard() {
    return _Section(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: _RoundIcon(Icons.verified_user_outlined, color: DF.primary600)),
          const SizedBox(height: 14),
          const Text('Sign in to place your order',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
          const SizedBox(height: 4),
          const Text(
            'Your basket is saved. Sign in or create an account and you will come straight back here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: DF.ink400, height: 1.45),
          ),
          const SizedBox(height: 20),
          PrimaryButton('Create an account',
              onPressed: () => AppRouter.push<bool>(context, const AuthScreen(register: true, returnOnSuccess: true))),
          const SizedBox(height: 10),
          OutlineButton('I already have an account',
              onPressed: () => AppRouter.push<bool>(context, const AuthScreen(returnOnSuccess: true))),
        ],
      ),
    );
  }

  /// The strip over the checkout: back, the step's title and the stepper.
  Widget _topBar() {
    return _Section(
      top: 0,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // The app bar already leaves checkout; this one steps back.
              if (step > 1)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Back',
                    onPressed: () => _goTo(step - 1),
                    icon: const Icon(Icons.arrow_back, size: 18, color: DF.ink700),
                  ),
                )
              else
                const SizedBox(width: 4),
              const SizedBox(width: 4),
              Expanded(
                child: Text(_stepTitles[step]!,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DF.ink900)),
              ),
              Text('Step $step of 3', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 4), child: _Stepper(step: step, onBack: _goTo)),
        ],
      ),
    );
  }

  /* -------------------------------------------------------- 1. address */

  Widget _field(String key, String label,
      {bool required = false,
      String? prefix,
      TextInputType? keyboard,
      int? maxLength,
      bool digits = false,
      Widget? hint,
      ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DFField(
          label: label,
          controller: f[key]!,
          required: required,
          prefix: prefix,
          keyboard: keyboard,
          maxLength: maxLength,
          digitsOnly: digits,
          error: errors[key],
          onChanged: onChanged ?? (_) => _clearError(key),
        ),
        if (hint != null && errors[key] == null) Padding(padding: const EdgeInsets.only(top: 0, bottom: 10), child: hint),
      ],
    );
  }

  Widget? get _pinHint {
    switch (lookupStatus) {
      case 'loading':
        return const Row(children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: DF.ink400)),
          SizedBox(width: 6),
          Text('Finding your area…', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
        ]);
      case 'found':
        return Row(children: [
          const Icon(Icons.location_on_outlined, size: 13, color: DF.primary600),
          const SizedBox(width: 4),
          Text('$lookupCity, $lookupState', style: const TextStyle(fontSize: 12.5, color: DF.primary600)),
        ]);
      case 'missing':
        return const Text('Enter the city and state below', style: TextStyle(fontSize: 12.5, color: DF.ink400));
    }
    return null;
  }

  Widget _addressStep() {
    final typed = f['area']!.text.trim().toLowerCase();
    final suggestions = areas.where((a) => a.toLowerCase() != typed && (typed.isEmpty || a.toLowerCase().contains(typed))).take(8).toList();

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('name', 'Full name', required: true, keyboard: TextInputType.name),
          _field('mobile', 'Mobile number', required: true, prefix: '+91', keyboard: TextInputType.phone, maxLength: 10, digits: true),
          _field('c_pincode', 'Pin code',
              required: true, keyboard: TextInputType.number, maxLength: 6, digits: true, hint: _pinHint, onChanged: _onPinChanged),
          _field('city', 'City', required: true),
          _field('state', 'State', required: true),
          _field('house_no', 'House no., building name', required: true),
          _field('area', 'Road name, area, colony', required: true, onChanged: (_) {
            _clearError('area');
            setState(() {});
          }),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in suggestions)
                    ActionChip(
                      label: Text(a, style: const TextStyle(fontSize: 12.5, color: DF.ink700)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: DF.lineStrong),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        f['area']!.text = a;
                        errors.remove('area');
                      }),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => showMore = !showMore),
              style: TextButton.styleFrom(foregroundColor: DF.primary700, padding: EdgeInsets.zero),
              icon: Icon(showMore ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(
                showMore ? 'Hide optional details' : 'Add landmark, email or delivery note (optional)',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (showMore) ...[
            const SizedBox(height: 8),
            _field('near_by', 'Nearby landmark'),
            _field('email', 'Email for the invoice', keyboard: TextInputType.emailAddress),
            _field('message', 'Delivery note'),
          ],
          const SizedBox(height: 6),
          const Text('Type of address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: DF.ink700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (id, icon) in [('Home', Icons.home_outlined), ('Work', Icons.work_outline)]) ...[
                _TypePill(label: id, icon: icon, on: addressType == id, onTap: () => setState(() => addressType = id)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /* -------------------------------------------------- 2. order summary */

  Widget _deliveringTo() {
    final a = address;
    if (a == null) return const SizedBox.shrink();
    final line1 =
        [a['house_no'], a['area'], if (str(a['near_by']).isNotEmpty) 'Near ${a['near_by']}'].map(str).where((s) => s.isNotEmpty).join(', ');
    final line2 = '${[a['city'], a['state']].map(str).where((s) => s.isNotEmpty).join(', ')} – ${a['c_pincode']}';
    return _Section(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.location_on_outlined, size: 18, color: DF.primary700)),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 13, color: DF.ink500, height: 1.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(
                    text: 'Deliver to ',
                    style: const TextStyle(fontSize: 13.5, color: DF.ink500),
                    children: [
                      TextSpan(text: str(a['name']), style: const TextStyle(fontWeight: FontWeight.w700, color: DF.ink900)),
                      TextSpan(text: '  ${a['address_type'] ?? ''}', style: const TextStyle(fontSize: 12, color: DF.ink400)),
                    ],
                  )),
                  const SizedBox(height: 2),
                  Text('$line1, $line2'),
                  Text('+91 ${a['mobile']}'),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _goTo(1),
            style: TextButton.styleFrom(
                foregroundColor: DF.primary700, padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
            child: const Text('Change', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<Widget> _summaryStep(AppState state) {
    final quoted = mapsOf(quote?['items']);
    return [
      _deliveringTo(),
      _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Items (${state.cartCount})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
            const SizedBox(height: 4),
            for (final (i, item) in state.cart.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(8)),
                      child: NetImage(Config.url(item.image)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DF.ink900, height: 1.35)),
                          const SizedBox(height: 2),
                          Text('Qty ${item.qty}', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPrice(toNum(quoted.where((q) => toInt(q['id']) == item.id).firstOrNull?['price'], item.price) * item.qty),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DF.ink900),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.local_offer_outlined, size: 16, color: DF.primary700),
              SizedBox(width: 8),
              Text('Have a coupon?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: couponInput,
                      style: const TextStyle(fontSize: 14, color: DF.ink900),
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _applyCoupon(),
                      decoration: const InputDecoration(
                        hintText: 'Enter coupon code',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton('Apply',
                    height: 40, radius: 8, fontSize: 14, color: DF.primary700, borderColor: DF.primary500, onPressed: _applyCoupon),
              ],
            ),
            if (couponError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(couponError, style: const TextStyle(fontSize: 13, color: DF.danger)),
            ],
            if (quote?['coupon'] is Map) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check, size: 14, color: DF.primary600),
                const SizedBox(width: 6),
                Text('Coupon ${quote!['coupon']['code']} applied', style: const TextStyle(fontSize: 13, color: DF.primary600)),
              ]),
            ],
          ],
        ),
      ),
    ];
  }

  /* ---------------------------------------------------------- 3. payment */

  List<Widget> _paymentStep() {
    final options = mapsOf(quote?['paymentOptions']);
    return [
      _deliveringTo(),
      _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Payment method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
            const SizedBox(height: 10),
            if (options.isEmpty)
              const Text('Loading payment options…', style: TextStyle(fontSize: 14, color: DF.ink400))
            else
              for (final (i, o) in options.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _PaymentOption(
                  label: str(o['label']),
                  ready: o['ready'] == true,
                  selected: payment == str(o['id']),
                  onTap: () => setState(() => payment = str(o['id'])),
                ),
              ],
            if (error.isNotEmpty) ...[const SizedBox(height: 12), ErrorNote(error)],
          ],
        ),
      ),
    ];
  }

  /* ------------------------------------------------------------ summary */

  Widget _summaryCard(AppState state) {
    final totals = (quote?['totals'] as Map?)?.cast<String, dynamic>();
    final count = state.cartCount;
    final chosen = mapsOf(quote?['paymentOptions']).where((o) => str(o['id']) == payment).firstOrNull;
    String v(String key) => totals == null ? '—' : formatPrice(toNum(totals[key]));
    final shipping = toNum(totals?['shipping']);

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Price details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
          const SizedBox(height: 8),
          _SummaryRow('Subtotal ($count item${count == 1 ? '' : 's'})', v('subtotal')),
          if (toNum(totals?['discount']) > 0)
            _SummaryRow('Coupon (${quote?['coupon']?['code'] ?? ''})', '− ${v('discount')}', success: true),
          _SummaryRow('GST', v('tax')),
          _SummaryRow('Shipping', totals == null ? '—' : (shipping > 0 ? formatPrice(shipping) : 'Free'),
              success: totals != null && shipping <= 0),
          const Divider(height: 14),
          _SummaryRow('Grand total', v('grandTotal'), strong: true),
          if (step == 3 && chosen != null) ...[
            const SizedBox(height: 8),
            Text.rich(TextSpan(
              text: 'Paying by ',
              style: const TextStyle(fontSize: 13, color: DF.ink500),
              children: [TextSpan(text: str(chosen['label']), style: const TextStyle(fontWeight: FontWeight.w600, color: DF.ink700))],
            )),
          ],
          if (quote != null && quote!['ok'] == false && str(quote!['error']).isNotEmpty) ...[
            const SizedBox(height: 10),
            ErrorNote(str(quote!['error'])),
          ],
        ],
      ),
    );
  }

  /// The secure-details line and the terms, compact under the page.
  Widget _secureNote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 13, color: DF.ink400),
              SizedBox(width: 6),
              Text('Your details are sent securely', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => AppRouter.open(context, '/legal/terms-and-conditions'),
            child: const Text.rich(
              TextSpan(
                text: 'By placing the order you agree to our ',
                style: TextStyle(fontSize: 12.5, color: DF.ink400),
                children: [
                  TextSpan(text: 'terms and conditions', style: TextStyle(color: DF.primary700)),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /* ----------------------------------------------------- online payment */

  Widget _paymentPanel() {
    final failed = payState == 'failed';
    final checking = payState == 'checking';
    return _Section(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: failed ? const Color(0x1AD92D20) : DF.primary50, shape: BoxShape.circle),
              child: checking
                  ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 2.5, color: DF.primary600))
                  : Icon(failed ? Icons.error_outline : Icons.credit_card, color: failed ? DF.danger : DF.primary600, size: 30),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            failed ? 'Payment not completed' : (checking ? 'Checking your payment…' : 'Waiting for payment'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900),
          ),
          const SizedBox(height: 4),
          Text(
            failed
                ? 'We have not received the payment for this order yet. You can pay again, or check once more if you just paid.'
                : 'Complete the payment in your browser, then come back to the app. Your order is confirmed as soon as the payment is received.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: DF.ink400, height: 1.45),
          ),
          const SizedBox(height: 20),
          PrimaryButton(failed ? 'Pay again' : 'Open payment page',
              onPressed: checking
                  ? null
                  : () {
                      setState(() => payState = 'waiting');
                      Native.open(pendingRedirect, context: context);
                    }),
          const SizedBox(height: 10),
          OutlineButton(failed ? 'Check again' : 'I have paid', onPressed: checking ? null : _checkPayment),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ small pieces */

/// The empty-state icon: a 48px glyph on a light brand circle.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, {this.color = DF.ink300});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
        child: Icon(icon, size: 40, color: color),
      );
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton(this.label, {required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: DF.primary600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.icon, required this.on, required this.onTap});
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? DF.primary700 : DF.ink500;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? DF.primary50 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? DF.primary500 : DF.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.label, required this.ready, required this.selected, required this.onTap});
  final String label;
  final bool ready;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = ready && selected;
    return InkWell(
      onTap: ready ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? DF.primary50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? DF.primary500 : (ready ? DF.lineStrong : DF.line)),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: on ? DF.primary600 : DF.ink300),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: ready ? DF.ink800 : DF.ink300)),
            ),
            if (!ready) const Text('Not available yet', style: TextStyle(fontSize: 12, color: DF.ink300)),
          ],
        ),
      ),
    );
  }
}

/// Address / Order Summary / Payment, one compact row; a finished step can
/// be tapped to go back to it, a later one cannot be jumped to.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.step, required this.onBack});
  final int step;
  final ValueChanged<int> onBack;

  static const _steps = [
    (1, 'Address'),
    (2, 'Summary'),
    (3, 'Payment'),
  ];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final (index, (n, label)) in _steps.indexed) {
      final done = n < step;
      final current = n == step;
      Widget item = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || current ? DF.primary600 : Colors.white,
              border: Border.all(color: done || current ? DF.primary600 : DF.lineStrong, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Center(
                    child:
                        Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: current ? Colors.white : DF.ink300))),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: current ? DF.ink900 : (done ? DF.primary700 : DF.ink400),
              )),
        ],
      );
      if (done) item = GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onBack(n), child: item);
      children.add(item);
      if (index < _steps.length - 1) {
        children.add(Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(minWidth: 8),
            decoration: BoxDecoration(color: done ? DF.primary500 : DF.line, borderRadius: BorderRadius.circular(2)),
          ),
        ));
      }
    }
    return Row(children: children);
  }
}
