import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../screens/account_screens.dart';
import 'ui.dart';

/// The bottom-sheet forms the site opens from many places: request a call
/// back, the sign-in prompt, the brochure / quotation form and the request
/// wizard.

/* ----------------------------------------------------------- call back */

/// "Request Call Back" — POST /api/forms/callback { name, mobile, timing }.
Future<void> showCallbackSheet(BuildContext context) {
  return showDFSheet(
    context,
    title: 'Request a call back',
    subtitle: 'Leave your number and our expert will call you.',
    builder: (_) => const _CallbackForm(),
  );
}

class _CallbackForm extends StatefulWidget {
  const _CallbackForm();
  @override
  State<_CallbackForm> createState() => _CallbackFormState();
}

class _CallbackFormState extends State<_CallbackForm> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  String timing = 'Anytime';
  bool busy = false;
  bool done = false;
  String? error;

  Future<void> _send() async {
    final m = normaliseMobile(mobile.text);
    if (name.text.trim().length < 2) return setState(() => error = 'Please enter your name.');
    if (!mobilePattern.hasMatch(m)) return setState(() => error = 'Please enter a valid 10 digit mobile number.');
    setState(() {
      busy = true;
      error = null;
    });
    final res = await Api.instance.post('/api/forms/callback', {'name': name.text.trim(), 'mobile': m, 'timing': timing});
    if (!mounted) return;
    setState(() {
      busy = false;
      done = res.ok;
      error = res.ok ? null : res.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (done) return const SuccessNote('Thank you — our expert will call you shortly.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DFField(label: 'Your name', controller: name, required: true),
        DFField(
            label: 'Mobile number',
            controller: mobile,
            required: true,
            keyboard: TextInputType.phone,
            digitsOnly: true,
            maxLength: 10,
            prefix: '+91'),
        const Text('Best time to call', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in const ['Anytime', 'Morning', 'Afternoon', 'Evening'])
              DFChip(t, selected: timing == t, onTap: () => setState(() => timing = t)),
          ],
        ),
        const SizedBox(height: 16),
        if (error != null) ErrorNote(error!),
        PrimaryButton('Request Call Back', loading: busy, onPressed: _send),
      ],
    );
  }
}

/* ------------------------------------------------------- sign-in prompt */

/// "Sign in to place your order" (components/auth/SignInPrompt.jsx).
/// Resolves true when the customer signed in from it.
Future<bool> showSignInPrompt(BuildContext context, {String title = 'Sign in to place your order'}) async {
  final result = await showDFSheet<bool>(
    context,
    title: title,
    subtitle: 'Your basket is saved. Sign in or create an account and you will come straight back here.',
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton('Create an account', onPressed: () async {
          final ok = await AppRouter.push<bool>(ctx, const AuthScreen(register: true, returnOnSuccess: true));
          if (ctx.mounted) Navigator.pop(ctx, ok == true);
        }),
        const SizedBox(height: 10),
        OutlineButton('I already have an account', onPressed: () async {
          final ok = await AppRouter.push<bool>(ctx, const AuthScreen(returnOnSuccess: true));
          if (ctx.mounted) Navigator.pop(ctx, ok == true);
        }),
        const SizedBox(height: 12),
        const Text('Signing in takes one OTP on your mobile number.', textAlign: TextAlign.center, style: DF.muted),
      ],
    ),
  );
  return result == true;
}

/* ------------------------------------------------- quotation / brochure */

/// "Download Brochure" — POST /api/quotation, then opens /api/brochure/<id>.
Future<void> showQuotationSheet(BuildContext context, int productId) {
  return showDFSheet(
    context,
    title: 'Get Quotation',
    subtitle: 'Share your details and download the brochure.',
    builder: (_) => _QuotationForm(productId: productId),
  );
}

class _QuotationForm extends StatefulWidget {
  const _QuotationForm({required this.productId});
  final int productId;
  @override
  State<_QuotationForm> createState() => _QuotationFormState();
}

class _QuotationFormState extends State<_QuotationForm> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  bool busy = false;
  bool done = false;
  String? error;

  Future<void> _send() async {
    final m = normaliseMobile(phone.text);
    if (name.text.trim().length < 2) return setState(() => error = 'Please enter your name.');
    if (!mobilePattern.hasMatch(m)) return setState(() => error = 'Please enter a valid 10 digit mobile number.');
    if (email.text.trim().isNotEmpty && !emailPattern.hasMatch(email.text.trim())) {
      return setState(() => error = 'Please enter a valid email.');
    }
    setState(() {
      busy = true;
      error = null;
    });
    final res = await Api.instance.post('/api/quotation', {
      'productId': widget.productId,
      'name': name.text.trim(),
      'phone': m,
      'email': email.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      done = res.ok;
      error = res.ok ? null : res.error;
    });
    if (res.ok) Native.openInApp(Config.url('/api/brochure/${widget.productId}'));
  }

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SuccessNote('Thank you — the brochure is downloading and our team will send you a quotation.'),
          const SizedBox(height: 12),
          OutlineButton('Download Brochure again',
              icon: Icons.download, onPressed: () => Native.openInApp(Config.url('/api/brochure/${widget.productId}'))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DFField(label: 'Name', controller: name, required: true),
        DFField(label: 'Email', controller: email, keyboard: TextInputType.emailAddress),
        DFField(
            label: 'Phone',
            controller: phone,
            required: true,
            keyboard: TextInputType.phone,
            digitsOnly: true,
            maxLength: 10,
            prefix: '+91'),
        if (error != null) ErrorNote(error!),
        PrimaryButton('Download Brochure', icon: Icons.download, loading: busy, onPressed: _send),
      ],
    );
  }
}

/* ------------------------------------------------------- request wizard */

/// "Submit your request / Our expert will call you back"
/// (components/forms/RequestWizard.jsx): what is needed → contact details →
/// verify the number. /api/wizard/options, /cities, /lead, /verify-otp.
Future<void> showRequestWizard(BuildContext context) {
  return showDFSheet(
    context,
    title: 'Submit your request',
    subtitle: 'Our expert will call you back',
    builder: (_) => const _RequestWizard(),
  );
}

class _RequestWizard extends StatefulWidget {
  const _RequestWizard();
  @override
  State<_RequestWizard> createState() => _RequestWizardState();
}

class _RequestWizardState extends State<_RequestWizard> {
  int step = 1;
  bool done = false;
  bool busy = false;
  String? error;

  List<Map<String, dynamic>> leadTypes = [];
  List<String> states = [];
  List<Map<String, dynamic>> cities = [];

  String complainType = '2';
  String serviceType = '2';
  String purchaseType = 'product';
  String premises = '1';
  String? leadType;
  String? state;
  String? city;

  final name = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final pincode = TextEditingController();
  final houseNo = TextEditingController();
  final area = TextEditingController();
  final nearBy = TextEditingController();
  final otp = TextEditingController();

  @override
  void initState() {
    super.initState();
    _options();
  }

  Future<void> _options() async {
    final res = await Api.instance.get('/api/wizard/options');
    if (!mounted) return;
    setState(() {
      leadTypes = mapsOf(res.map['leadTypes']);
      states = ((res.map['states'] as List?) ?? const []).map((e) => '$e').toList();
    });
  }

  Future<void> _cities(String s) async {
    setState(() {
      cities = [];
      city = null;
    });
    final res = await Api.instance.get('/api/wizard/cities', query: {'state': s});
    if (!mounted) return;
    setState(() => cities = mapsOf(res.map['cities']));
  }

  Future<void> _submit() async {
    final m = normaliseMobile(mobile.text);
    if (name.text.trim().length < 2) return setState(() => error = 'Please enter your name.');
    if (!mobilePattern.hasMatch(m)) return setState(() => error = 'Please enter a valid 10 digit mobile number.');
    if (state == null || city == null) return setState(() => error = 'Please choose your state and city.');
    setState(() {
      busy = true;
      error = null;
    });
    final res = await Api.instance.post('/api/wizard/lead', {
      'name': name.text.trim(),
      'mobile': m,
      'email': email.text.trim(),
      'leadType': leadType,
      'state': state,
      'city': city,
      'pincode': pincode.text.trim(),
      'complainType': complainType,
      'serviceType': serviceType,
      'purchaseType': purchaseType,
      'domesticOrCommercial': premises,
      'houseNo': houseNo.text.trim(),
      'area': area.text.trim(),
      'nearBy': nearBy.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!res.ok) {
        error = res.error;
      } else if (res.map['otpRequired'] == true) {
        step = 3;
      } else {
        done = true;
      }
    });
  }

  Future<void> _verify() async {
    if (otp.text.trim().length < 4) return setState(() => error = 'Enter the code we sent.');
    setState(() {
      busy = true;
      error = null;
    });
    final res = await Api.instance.post('/api/wizard/verify-otp', {'mobile': normaliseMobile(mobile.text), 'otp': otp.text.trim()});
    if (!mounted) return;
    setState(() {
      busy = false;
      done = res.ok;
      error = res.ok ? null : res.error;
    });
  }

  Widget _group(String label, List<List<String>> options, String value, ValueChanged<String> onPick) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: DF.ink700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final o in options) DFChip(o[1], selected: value == o[0], onTap: () => onPick(o[0]))],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (done) return const SuccessNote('Thank you — your request is in. Our expert will call you back shortly.');
    final isService = complainType == '2';

    final steps = Row(
      children: [
        for (final (i, label) in const ['Requirement', 'Details', 'Verify'].indexed)
          if (i < (step == 3 ? 3 : 2))
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: i + 1 <= step ? DF.primary600 : DF.line,
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 11, color: i + 1 <= step ? Colors.white : DF.ink400, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: i + 1 <= step ? DF.ink900 : DF.ink400)),
                ],
              ),
            ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        steps,
        const SizedBox(height: 16),
        if (step == 1) ...[
          _group(
              'I need',
              const [
                ['2', 'Service'],
                ['1', 'New Purchase']
              ],
              complainType,
              (v) => setState(() => complainType = v)),
          if (isService)
            _group(
                'Type of service',
                const [
                  ['2', 'Repair / Service'],
                  ['1', 'Installation / Uninstallation'],
                  ['3', 'AMC']
                ],
                serviceType,
                (v) => setState(() => serviceType = v))
          else
            _group(
                'Looking for',
                const [
                  ['product', 'Product'],
                  ['spare_parts', 'Spare Parts']
                ],
                purchaseType,
                (v) => setState(() => purchaseType = v)),
          _group(
              'For',
              const [
                ['1', 'Home'],
                ['2', 'Commercial']
              ],
              premises,
              (v) => setState(() => premises = v)),
          DFDropdown(
            label: 'Product category',
            required: true,
            hint: 'Choose a category',
            items: leadTypes.map((t) => '${t['name']}').toList(),
            value: leadTypes.where((t) => '${t['id']}' == leadType).map((t) => '${t['name']}').firstOrNull,
            onChanged: (v) => setState(() => leadType = '${leadTypes.firstWhere((t) => t['name'] == v)['id']}'),
          ),
          if (error != null) ErrorNote(error!),
          PrimaryButton('Continue', onPressed: () {
            if (leadType == null) return setState(() => error = 'Please choose a product category.');
            setState(() {
              error = null;
              step = 2;
            });
          }),
        ] else if (step == 2) ...[
          DFField(label: 'Full name', controller: name, required: true, hint: 'Your name'),
          DFField(
              label: 'Mobile number',
              controller: mobile,
              required: true,
              keyboard: TextInputType.phone,
              digitsOnly: true,
              maxLength: 10,
              hint: '10 digits'),
          DFField(label: 'Email (optional)', controller: email, keyboard: TextInputType.emailAddress, hint: 'you@email.com'),
          DFDropdown(
              label: 'State',
              required: true,
              items: states,
              value: state,
              onChanged: (v) {
                setState(() => state = v);
                if (v != null) _cities(v);
              }),
          DFDropdown(
            label: 'City',
            required: true,
            hint: state == null ? 'State first' : 'Select',
            items: cities.map((c) => '${c['name']}').toList(),
            value: city,
            onChanged: (v) => setState(() => city = v),
          ),
          const Text('Address (optional)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: DFField(label: 'Pin code', controller: pincode, keyboard: TextInputType.number, digitsOnly: true, maxLength: 6)),
            const SizedBox(width: 8),
            Expanded(child: DFField(label: 'House no.', controller: houseNo)),
          ]),
          Row(children: [
            Expanded(child: DFField(label: 'Area / road', controller: area)),
            const SizedBox(width: 8),
            Expanded(child: DFField(label: 'Landmark', controller: nearBy)),
          ]),
          if (error != null) ErrorNote(error!),
          Row(children: [
            OutlineButton('Back', onPressed: () => setState(() => step = 1)),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton('Submit request', loading: busy, onPressed: _submit)),
          ]),
        ] else ...[
          const Text('Verify your number', style: DF.h2),
          const SizedBox(height: 4),
          Text('We sent a code to +91 ${normaliseMobile(mobile.text)}.', style: DF.muted),
          const SizedBox(height: 14),
          DFField(
              label: 'Verification code', controller: otp, keyboard: TextInputType.number, digitsOnly: true, maxLength: 6, hint: '······'),
          if (error != null) ErrorNote(error!),
          Row(children: [
            OutlineButton('Back', onPressed: () => setState(() => step = 2)),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton('Verify', loading: busy, onPressed: _verify)),
          ]),
        ],
      ],
    );
  }
}
