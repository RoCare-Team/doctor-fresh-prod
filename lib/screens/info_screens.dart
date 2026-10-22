import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/html_view.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

/// The site's information pages: contact, become a partner, store locator,
/// careers and the policy documents (app/(shop)/contact, partner,
/// store-locator, careers, legal/[slug] with components/forms/* and
/// components/careers/CareersBoard.jsx).

/* ---------------------------------------------------------- shared parts */

/// The page body: white blocks on the grey canvas, pull to refresh where it loads.
class _Page extends StatelessWidget {
  const _Page({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(padding: const EdgeInsets.only(bottom: 24), children: children);
    return onRefresh == null ? list : RefreshIndicator(color: DF.primary600, onRefresh: onRefresh!, child: list);
  }
}

/// One white block of the page on the grey canvas, 8px apart.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
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

const _h2 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900);
const _muted = TextStyle(fontSize: 13, height: 1.45, color: DF.ink400);

/// A round icon on the light brand tint, as the list rows open with.
Widget _roundIcon(IconData icon, {double size = 40}) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.45, color: DF.primary700),
    );

/// The green / red line under a sent form (components/forms/Field.jsx `FormNote`).
Widget _formNote(String status, String error, {String done = 'Thank you — our team will contact you shortly.'}) {
  if (status == 'done') return SuccessNote(done);
  if (status == 'error') {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: DF.danger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Text(error, style: const TextStyle(fontSize: 13.5, color: DF.danger)),
    );
  }
  return const SizedBox.shrink();
}

/// What a failed form says when the site sent no reason (lib/forms.js).
String _formError(ApiResult res) =>
    res.map['error'] is String ? res.error : (res.networkError ? res.error : 'Something went wrong. Please call +91-9311587716.');

/* --------------------------------------------------------------- contact */

/// "Contact us" — the quick ways to reach the team and the form
/// (app/(shop)/contact/page.jsx + components/forms/ContactForm.jsx).
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final message = TextEditingController();
  String status = 'idle';
  String error = '';

  Future<void> _send() async {
    final m = normaliseMobile(mobile.text);
    String? problem;
    if (name.text.trim().isEmpty || mobile.text.trim().isEmpty || email.text.trim().isEmpty || message.text.trim().isEmpty) {
      problem = 'Please fill in every field.';
    } else if (m.length != 10) {
      problem = 'Enter a valid 10-digit mobile number.';
    } else if (!emailPattern.hasMatch(email.text.trim())) {
      problem = 'Enter a valid email address.';
    }
    if (problem != null) {
      return setState(() {
        status = 'error';
        error = problem!;
      });
    }
    setState(() => status = 'sending');
    final res = await Api.instance.post('/api/forms/contact', {
      'enquiry_type': 'Contact Form',
      'name': name.text.trim(),
      'mobile': m,
      'email': email.text.trim(),
      'message': message.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        status = 'done';
        for (final c in [name, mobile, email, message]) {
          c.clear();
        }
      } else {
        status = 'error';
        error = _formError(res);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = AppScope.of(context).brand;
    final phone = str(brand['phone']).isNotEmpty ? str(brand['phone']) : Config.phone;
    final phoneRaw = str(brand['phoneRaw']).isNotEmpty ? str(brand['phoneRaw']) : Config.phoneRaw;
    final mail = str(brand['email']).isNotEmpty ? str(brand['email']) : Config.email;
    final whatsapp = str(brand['whatsapp']).isNotEmpty ? str(brand['whatsapp']) : Config.whatsapp;
    final website = str(brand['website']).isNotEmpty ? str(brand['website']) : 'www.doctorfresh.in';
    final offices = mapsOf(brand['offices']);
    final sending = status == 'sending';

    Widget tile(IconData icon, String label, String value, VoidCallback onTap) => Expanded(
          child: Material(
            color: DF.canvas,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Column(
                  children: [
                    _roundIcon(icon, size: 38),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DF.ink900)),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, color: DF.ink400)),
                  ],
                ),
              ),
            ),
          ),
        );
    Widget info(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: DF.primary700)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                    const SizedBox(height: 2),
                    Text(value, style: _muted),
                  ],
                ),
              ),
            ],
          ),
        );

    return DFScaffold(
      title: 'Contact us',
      body: _Page(
        children: [
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    tile(Icons.phone_outlined, 'Call', phone, () => Native.call(phoneRaw)),
                    const SizedBox(width: 8),
                    tile(Icons.chat_bubble_outline, 'WhatsApp', phoneRaw, () => Native.open(whatsapp, context: context)),
                    const SizedBox(width: 8),
                    tile(Icons.mail_outline, 'Email', mail, () => Native.email(mail)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Send us a message', style: _h2),
                const SizedBox(height: 2),
                const Text('Sales, service, spare parts or partnership — we reply within one working day.', style: _muted),
                const SizedBox(height: 14),
                DFField(label: 'Name', controller: name, required: true, hint: 'Name'),
                DFField(
                    label: 'Mobile',
                    controller: mobile,
                    required: true,
                    hint: 'Mobile',
                    keyboard: TextInputType.phone,
                    digitsOnly: true,
                    maxLength: 10),
                DFField(label: 'Email', controller: email, required: true, hint: 'Email', keyboard: TextInputType.emailAddress),
                DFField(label: 'Message', controller: message, required: true, hint: 'Message', maxLines: 4),
                const SizedBox(height: 4),
                PrimaryButton(sending ? 'Sending…' : 'Send message', onPressed: sending ? null : _send),
                if (status == 'done' || status == 'error') ...[const SizedBox(height: 12), _formNote(status, error)],
              ],
            ),
          ),
          _Section(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('More ways to reach us', style: _h2),
                const SizedBox(height: 2),
                for (final o in offices) ...[
                  info(Icons.location_on_outlined, str(o['label']), str(o['address'])),
                  const Divider(height: 1),
                ],
                info(Icons.language, 'Website', website),
                const Divider(height: 1),
                info(Icons.schedule, 'Service response', 'Service within 24 hours across serviced cities'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------------- partner */

/// "Become A Partner" (app/(shop)/partner/page.jsx + components/forms/PartnerForm.jsx).
class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  static const _tabs = ['Become A Dealer', 'Become A Distributor', 'Become A C&F/Master'];
  static const _benefits = [
    (Icons.trending_up, 'Growing category', 'Water treatment demand across domestic, commercial and industrial segments.'),
    (Icons.inventory_2_outlined, 'Full product range', 'Purifiers, RO plants, softeners, ionizers, ATMs, STP/ETP and spare parts.'),
    (Icons.headset_mic_outlined, 'Service backup', 'Trained technician network and genuine spare parts supply.'),
    (Icons.handshake_outlined, 'Territory support', 'Marketing material, pricing support and lead sharing in your area.'),
  ];
  static const _investment = ['50k - 1 Lakh', '1 Lakh - 2.5 Lakh', '2.5 Lakh - 5 Lakh'];
  static const _education = ['10th', '12th', 'Graduate', 'Post Graduate'];

  int active = 0;
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final business = TextEditingController();
  final address = TextEditingController();
  String? investment;
  String? education;
  String? state;
  String? city;
  List<String> states = [];
  Map<String, List<String>> citiesByState = {};
  List<String> cities = [];
  String status = 'idle';
  String error = '';

  @override
  void initState() {
    super.initState();
    _states();
  }

  /// Every state with its cities, from the site's own lists.
  Future<void> _states() async {
    final res = await Api.instance.get('/api/get_backlinks_city');
    final list = mapsOf(res.map['states']);
    if (list.isNotEmpty) {
      if (!mounted) return;
      return setState(() {
        states = list.map((s) => str(s['state'])).where((s) => s.isNotEmpty).toList();
        citiesByState = {for (final s in list) str(s['state']): ((s['cities'] as List?) ?? const []).map((e) => '$e').toList()};
      });
    }
    final alt = await Api.instance.get('/api/wizard/options');
    if (!mounted) return;
    setState(() {
      states = ((alt.map['states'] as List?) ?? const [])
          .map((e) => e is Map ? str(e['name'] ?? e['state'] ?? e['label']) : '$e')
          .where((s) => s.isNotEmpty)
          .toList();
    });
  }

  Future<void> _cities(String s) async {
    setState(() {
      city = null;
      cities = citiesByState[s] ?? [];
    });
    final res = await Api.instance.get('/api/forms/cities', query: {'state': s});
    final list = ((res.map['cities'] as List?) ?? const []).map((e) => '$e').toList();
    if (!mounted || state != s || list.isEmpty) return;
    setState(() => cities = list);
  }

  Future<void> _send() async {
    final values = [name.text, email.text, mobile.text, business.text, investment, education, state, city, address.text];
    if (values.any((v) => (v ?? '').trim().isEmpty)) {
      return setState(() {
        status = 'error';
        error = 'Please fill in every field.';
      });
    }
    setState(() => status = 'sending');
    final res = await Api.instance.post('/api/forms/partner', {
      'enquiry_type': _tabs[active],
      'name': name.text.trim(),
      'email': email.text.trim(),
      'mobile': normaliseMobile(mobile.text),
      'business': business.text.trim(),
      'investment_capacity': investment,
      'education': education,
      'state': state,
      'city': city,
      'address': address.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        status = 'done';
        for (final c in [name, email, mobile, business, address]) {
          c.clear();
        }
        investment = education = state = city = null;
        cities = [];
      } else {
        status = 'error';
        error = _formError(res);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = AppScope.of(context).brand;
    final phone = str(brand['phone']).isNotEmpty ? str(brand['phone']) : Config.phone;
    final phoneRaw = str(brand['phoneRaw']).isNotEmpty ? str(brand['phoneRaw']) : Config.phoneRaw;
    final mail = str(brand['email']).isNotEmpty ? str(brand['email']) : Config.email;
    final sending = status == 'sending';

    return DFScaffold(
      title: 'Become a partner',
      body: _Page(
        children: [
          // the partnership type
          Container(
            margin: const EdgeInsets.only(top: 8),
            color: Colors.white,
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(
                child: DFChip(
                  _tabs[i],
                  selected: i == active,
                  onTap: () => setState(() {
                    active = i;
                    status = 'idle';
                    error = '';
                  }),
                ),
              ),
            ),
          ),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Partner application', style: _h2),
                const SizedBox(height: 2),
                const Text('Dealer, distributor or C&F / master franchise — build a water purification business in your territory.',
                    style: _muted),
                const SizedBox(height: 14),
                DFField(label: 'First name', controller: name, required: true, hint: 'First Name'),
                DFField(label: 'Email', controller: email, required: true, hint: 'Email', keyboard: TextInputType.emailAddress),
                DFField(
                    label: 'Phone number',
                    controller: mobile,
                    required: true,
                    hint: 'Phone Number',
                    keyboard: TextInputType.phone,
                    digitsOnly: true,
                    maxLength: 10),
                DFField(label: 'Business name', controller: business, required: true, hint: 'Business Name'),
                DFDropdown(
                  key: ValueKey('inv-$investment'),
                  label: 'Investment capacity',
                  required: true,
                  hint: 'Select investment capacity',
                  items: _investment,
                  value: investment,
                  onChanged: (v) => setState(() => investment = v),
                ),
                DFDropdown(
                  key: ValueKey('edu-$education'),
                  label: 'Education',
                  required: true,
                  hint: 'Select education',
                  items: _education,
                  value: education,
                  onChanged: (v) => setState(() => education = v),
                ),
                DFDropdown(
                  key: ValueKey('state-$state-${states.length}'),
                  label: 'State',
                  required: true,
                  hint: 'State Name',
                  items: states,
                  value: state,
                  onChanged: (v) {
                    setState(() => state = v);
                    if (v != null) _cities(v);
                  },
                ),
                DFDropdown(
                  key: ValueKey('city-$state-$city-${cities.length}'),
                  label: 'City',
                  required: true,
                  hint: state == null ? 'City Name' : 'Select city',
                  items: cities,
                  value: city,
                  onChanged: (v) => setState(() => city = v),
                ),
                DFField(label: 'Address', controller: address, required: true, hint: 'address', maxLines: 3),
                const SizedBox(height: 4),
                PrimaryButton(sending ? 'Submitting…' : 'Apply — ${_tabs[active]}', onPressed: sending ? null : _send),
                if (status == 'done' || status == 'error') ...[
                  const SizedBox(height: 12),
                  _formNote(status, error, done: 'Application received — our channel partner team will contact you shortly.'),
                ],
              ],
            ),
          ),
          _Section(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Why partner with us', style: _h2),
                const SizedBox(height: 2),
                for (final (i, (icon, title, text)) in _benefits.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _roundIcon(icon, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                              const SizedBox(height: 2),
                              Text(text, style: _muted),
                            ],
                          ),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Prefer to talk first?', style: _h2),
                const SizedBox(height: 2),
                const Text('Our channel team can walk you through investment, margins and territory availability.', style: _muted),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlineButton(phone,
                          icon: Icons.phone_outlined,
                          height: 42,
                          fontSize: 13.5,
                          color: DF.primary700,
                          borderColor: DF.lineStrong,
                          onPressed: () => Native.call(phoneRaw)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlineButton('Email us',
                          icon: Icons.mail_outline,
                          height: 42,
                          fontSize: 13.5,
                          color: DF.primary700,
                          borderColor: DF.lineStrong,
                          onPressed: () => Native.email(mail)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- stores */

/// "Store locations" (app/(shop)/store-locator/page.jsx).
class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Store locator',
      body: Loader(
        load: () => Api.instance.get('/api/mobile/page', query: {'type': 'stores'}),
        builder: (context, data, reload) {
          final locations = mapsOf(data['locations']);
          if (locations.isEmpty) {
            return const _Empty(icon: Icons.storefront_outlined, title: 'No stores listed yet', note: 'Please check back soon.');
          }
          return _Page(
            onRefresh: reload,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Visit us for product demos, spare parts and service support.', style: _muted),
              ),
              for (final s in locations) _StoreRow(store: s),
            ],
          );
        },
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store});
  final Map<String, dynamic> store;

  void _directions(BuildContext context) {
    final s = store;
    final map = str(s['mapLink']);
    Native.open(
      map.isNotEmpty
          ? map
          : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${str(s['branch'])}, ${str(s['address'])}')}',
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    final phone = str(s['phone']);
    Widget action(IconData icon, String tip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: DF.primary50,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: tip,
              visualDensity: VisualDensity.compact,
              onPressed: onTap,
              icon: Icon(icon, size: 18, color: DF.primary700),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roundIcon(Icons.storefront_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(s['branch']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DF.ink900)),
                if (str(s['city']).isNotEmpty)
                  Text(str(s['city']), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DF.primary700)),
                const SizedBox(height: 4),
                Text(str(s['address']), style: _muted),
                if (str(s['time']).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.schedule, size: 13, color: DF.ink400),
                    const SizedBox(width: 6),
                    Expanded(child: Text(str(s['time']), style: const TextStyle(fontSize: 12.5, color: DF.ink400))),
                  ]),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(phone, style: const TextStyle(fontSize: 12.5, color: DF.ink500)),
                ],
              ],
            ),
          ),
          if (phone.isNotEmpty) action(Icons.phone_outlined, 'Call', () => Native.call(phone.replaceAll(RegExp(r'\s'), ''))),
          action(Icons.near_me_outlined, 'Get directions', () => _directions(context)),
        ],
      ),
    );
  }
}

/// Nothing to show: an icon, one bold line and one muted line.
class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.note});
  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                child: Icon(icon, size: 48, color: DF.ink300),
              ),
              const SizedBox(height: 14),
              Text(title, style: _h2),
              const SizedBox(height: 4),
              Text(note, textAlign: TextAlign.center, style: _muted),
            ],
          ),
        ),
      );
}

/* --------------------------------------------------------------- careers */

/// "Opportunities" — the open jobs and the application form
/// (app/(shop)/careers/page.jsx + components/careers/CareersBoard.jsx).
class CareersScreen extends StatelessWidget {
  const CareersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Careers',
      body: Loader(
        load: () => Api.instance.get('/api/mobile/page', query: {'type': 'careers'}),
        builder: (context, data, reload) {
          final jobs = mapsOf(data['jobs']);
          final intro = str(data['intro']);
          return _Page(
            onRefresh: reload,
            children: [
              if (jobs.isNotEmpty)
                _Section(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(TextSpan(
                        text: 'Current openings',
                        style: _h2,
                        children: [
                          TextSpan(
                              text: '  ${jobs.length}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink400))
                        ],
                      )),
                      const SizedBox(height: 4),
                      for (final (i, j) in jobs.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _JobCard(job: j),
                      ],
                    ],
                  ),
                ),
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(jobs.isNotEmpty ? 'Don’t see the right role?' : 'Current openings', style: _h2),
                    const SizedBox(height: 2),
                    Text(
                      jobs.isNotEmpty
                          ? 'Send us your CV anyway — we will get in touch when a suitable role opens in your area.'
                          : 'Openings are published as they become available. Send your CV to our team and we will get in touch when a suitable role opens in your area.',
                      style: _muted,
                    ),
                    const SizedBox(height: 14),
                    const _ApplyForm(jobId: 0),
                  ],
                ),
              ),
              if (intro.isNotEmpty)
                _Section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('About working with us', style: _h2),
                      const SizedBox(height: 4),
                      Text(intro, style: _muted),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  const _JobCard({required this.job});
  final Map<String, dynamic> job;

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool open = false;
  bool applying = false;

  Widget _chip(IconData icon, String text, {bool primary = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: primary ? DF.primary50 : DF.surfaceMuted, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: primary ? DF.primary800 : DF.ink700),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 13, color: primary ? DF.primary800 : DF.ink700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final description = str(j['description']);
    final long = description.length > 220;
    final positions = toInt(j['positions']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _roundIcon(Icons.work_outline, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(j['title']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DF.ink900)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (str(j['location']).isNotEmpty) _chip(Icons.location_on_outlined, str(j['location'])),
                        if (str(j['jobType']).isNotEmpty) _chip(Icons.schedule, str(j['jobType'])),
                        if (str(j['experience']).isNotEmpty) _chip(Icons.school_outlined, str(j['experience'])),
                        if (positions > 0) _chip(Icons.group_outlined, '$positions opening${positions == 1 ? '' : 's'}', primary: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (!applying) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: () => setState(() => applying = true),
                    style: FilledButton.styleFrom(
                      backgroundColor: DF.primary600,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description,
                maxLines: !open && long ? 3 : null,
                overflow: !open && long ? TextOverflow.ellipsis : null,
                style: const TextStyle(fontSize: 13.5, height: 1.5, color: DF.ink500)),
            if (long)
              InkWell(
                onTap: () => setState(() => open = !open),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(open ? 'Show less' : 'Read full details',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DF.primary700)),
                      Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: DF.primary700),
                    ],
                  ),
                ),
              ),
          ],
          if (applying) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Apply for ${str(j['title'])}',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DF.ink900)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => applying = false),
                        icon: const Icon(Icons.close, size: 16, color: DF.ink400),
                      ),
                    ],
                  ),
                  _ApplyForm(jobId: toInt(j['id']), onClose: () => setState(() => applying = false)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The application — for one opening, or a general application (jobId 0).
class _ApplyForm extends StatefulWidget {
  const _ApplyForm({required this.jobId, this.onClose});
  final int jobId;
  final VoidCallback? onClose;

  @override
  State<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends State<_ApplyForm> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final city = TextEditingController();
  final message = TextEditingController();
  PickedFile? file;
  String status = 'idle';
  String error = '';

  static const _types = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  Future<void> _pick() async {
    final picked = await Native.pickFile();
    if (picked == null || !mounted) return;
    final ext = picked.name.split('.').last.toLowerCase();
    if (!_types.containsKey(ext) && !_types.containsValue(picked.mime)) {
      return setState(() {
        status = 'error';
        error = 'Attach a PDF, Word file or photo.';
      });
    }
    setState(() {
      file = picked;
      if (status == 'error') status = 'idle';
    });
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty || email.text.trim().isEmpty || city.text.trim().isEmpty) {
      return setState(() {
        status = 'error';
        error = 'Please fill in every required field.';
      });
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone.text.trim())) {
      return setState(() {
        status = 'error';
        error = 'Enter a valid 10-digit mobile number.';
      });
    }
    final f = file;
    if (f != null && f.bytes.length > 4 * 1024 * 1024) {
      return setState(() {
        status = 'error';
        error = 'The CV must be 4 MB or smaller.';
      });
    }
    setState(() {
      status = 'sending';
      error = '';
    });
    final ext = f?.name.split('.').last.toLowerCase() ?? '';
    final res = await Api.instance.multipart(
      '/api/careers/apply',
      fields: {
        'website': '',
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'city': city.text.trim(),
        'message': message.text.trim(),
        'jobId': '${widget.jobId}',
      },
      fileField: f == null ? null : 'resume',
      fileName: f?.name,
      fileBytes: f?.bytes,
      fileType: f == null ? null : (_types[ext] ?? f.mime),
    );
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        status = 'done';
        file = null;
        for (final c in [name, phone, email, city, message]) {
          c.clear();
        }
      } else {
        status = 'error';
        error = res.map['error'] is String ? res.error : (res.networkError ? res.error : 'Could not send your application.');
      }
    });
  }

  Widget _input(TextEditingController c, String hint, {TextInputType? keyboard, int lines = 1, bool digits = false, int? max}) => DFField(
        label: hint.replaceAll(' *', ''),
        required: hint.endsWith('*'),
        controller: c,
        hint: hint,
        keyboard: keyboard,
        maxLines: lines,
        digitsOnly: digits,
        maxLength: max,
      );

  @override
  Widget build(BuildContext context) {
    if (status == 'done') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DF.success.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DF.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 28, color: DF.success),
            const SizedBox(height: 8),
            const Text('Application sent', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: DF.ink900)),
            const SizedBox(height: 4),
            const Text('Thank you — our team will call you if your profile matches.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: DF.ink500)),
            if (widget.onClose != null)
              TextButton(
                onPressed: widget.onClose,
                child: const Text('Close', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.primary700)),
              ),
          ],
        ),
      );
    }
    final sending = status == 'sending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _input(name, 'Full name *', max: 100),
        _input(phone, 'Mobile number *', keyboard: TextInputType.phone, digits: true, max: 10),
        _input(email, 'Email *', keyboard: TextInputType.emailAddress, max: 120),
        _input(city, 'Your city *', max: 50),
        _input(message, 'Tell us about your experience (optional)', lines: 3, max: 5000),
        InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            painter: _DashedBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: DF.primary700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(file?.name ?? 'Attach your CV — PDF, Word or photo, up to 4 MB',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: DF.ink500)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (status == 'error') ...[
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(fontSize: 13.5, color: DF.danger)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            PrimaryButton(sending ? 'Sending…' : 'Submit application',
                icon: Icons.send_outlined, height: 44, radius: 8, loading: sending, onPressed: _submit),
            if (widget.onClose != null) ...[
              const SizedBox(width: 12),
              TextButton(onPressed: widget.onClose, child: const Text('Cancel', style: TextStyle(fontSize: 14, color: DF.ink500))),
            ],
          ],
        ),
      ],
    );
  }
}

/// The dashed outline of the CV picker.
class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DF.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* ----------------------------------------------------------------- legal */

/// A policy document (app/(shop)/legal/[slug]/page.jsx).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Policy',
      body: Loader(
        load: () => Api.instance.get('/api/mobile/page', query: {'type': 'legal', 'slug': slug}),
        builder: (context, data, reload) {
          final title = str(data['title']);
          return _Page(
            onRefresh: reload,
            children: [
              _Section(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DF.ink900)),
                      const SizedBox(height: 10),
                    ],
                    HtmlView(str(data['html']), onLink: (href) => AppRouter.open(context, href)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
