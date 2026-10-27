import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tabs.dart';
import '../core/native.dart';
import '../core/purifier.dart';
import '../core/theme.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';
import 'water_check_screen.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "In 12 days", "Today", "Overdue by 4 days".
String _due(int days) {
  if (days == 0) return 'Due today';
  if (days > 0) return days == 1 ? 'Due tomorrow' : 'In $days days';
  return days == -1 ? 'Overdue by 1 day' : 'Overdue by ${-days} days';
}

Color _tone(double left) => left > 0.35
    ? DF.success
    : left > 0.1
        ? DF.warning
        : DF.danger;

/// My Purifier: the customer's own purifier, its service and filter health,
/// reminders before they come due, and the service history.
class PurifierScreen extends StatelessWidget {
  const PurifierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Purifier?>(
      valueListenable: PurifierStore.instance.current,
      builder: (context, p, _) => DFScaffold(
        title: 'My purifier',
        showCart: false,
        actions: [
          if (p != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, color: DF.ink700),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PurifierForm(existing: p))),
            ),
        ],
        body: p == null ? const _Intro() : _Dashboard(p: p),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.speed_rounded, 'Filter health at a glance', 'See how much life is left in the filters and when the next service is due.'),
      (Icons.notifications_active_outlined, 'Reminders before it is due', 'A notification three days ahead, so the water never goes unfiltered.'),
      (Icons.history_rounded, 'Your service history', 'Every service and filter change, kept on your phone.'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [DF.primary50, Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DF.primary100),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: DF.primary100, shape: BoxShape.circle),
                child: const Icon(Icons.water_drop_rounded, size: 38, color: DF.primary700),
              ),
              const SizedBox(height: 14),
              const Text('Track your water purifier', style: DF.h2, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text('Add your purifier once. The app keeps count of its service and filter life and reminds you in time.',
                  style: DF.muted, textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final (icon, title, text) in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DFCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: DF.primary600, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900)),
                        const SizedBox(height: 2),
                        Text(text, style: const TextStyle(fontSize: 13, color: DF.ink400, height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        PrimaryButton('Add my purifier',
            icon: Icons.add_rounded,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PurifierForm()))),
        const SizedBox(height: 10),
        OutlineButton('Check my water first',
            icon: Icons.science_outlined,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WaterCheckScreen()))),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.p});
  final Purifier p;

  @override
  Widget build(BuildContext context) {
    final serviceDays = Purifier.daysUntil(p.nextService);
    final filterDays = Purifier.daysUntil(p.nextFilterChange);
    final urgent = serviceDays <= 3 || filterDays <= 7;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        DFCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.water_drop_rounded, color: DF.primary700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.brand.isEmpty ? 'My purifier' : p.brand, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: DF.ink900)),
                    const SizedBox(height: 2),
                    Text('${p.type} · installed ${_day(p.installedOn)}', style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Gauge(label: 'Service', left: p.serviceLeft, days: serviceDays, date: p.nextService)),
            const SizedBox(width: 12),
            Expanded(child: _Gauge(label: 'Filters', left: p.filterLeft, days: filterDays, date: p.nextFilterChange)),
          ],
        ),
        const SizedBox(height: 12),
        if (urgent)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: DF.warning.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: DF.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Your purifier needs attention soon. Book a technician now and pick a time that suits you.',
                      style: TextStyle(fontSize: 13, color: DF.ink700, height: 1.45)),
                ),
              ],
            ),
          ),
        PrimaryButton('Book a service', icon: Icons.build_outlined, onPressed: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          AppTabs.current.value = AppTabs.services;
        }),
        const SizedBox(height: 10),
        OutlineButton('Mark a service as done', icon: Icons.task_alt_rounded, onPressed: () => _markDone(context)),
        const SizedBox(height: 18),
        DFCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: [
              SwitchListTile(
                value: p.reminders,
                activeTrackColor: DF.primary600,
                title: const Text('Reminders', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900)),
                subtitle: const Text('A notification 3 days before a service or filter change', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
                onChanged: (on) async {
                  if (on && !await Native.requestNotifications()) {
                    if (context.mounted) toast(context, 'Allow notifications for Doctor Fresh in Settings to get reminders.');
                    return;
                  }
                  p.reminders = on;
                  await PurifierStore.instance.save(p);
                },
              ),
              const Divider(height: 1, color: DF.line),
              ListTile(
                leading: const Icon(Icons.science_outlined, color: DF.primary600),
                title: const Text('Water quality', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: DF.ink900)),
                subtitle: Text(p.tds == null ? 'Find the right purifier for your water' : 'Input water TDS: ${p.tds} ppm',
                    style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                trailing: const Icon(Icons.chevron_right_rounded, color: DF.ink300),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaterCheckScreen(initialTds: p.tds))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Service history', size: 18),
        const SizedBox(height: 8),
        DFCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final d in p.log)
                _HistoryRow(icon: Icons.build_circle_outlined, title: 'Service done', date: d),
              _HistoryRow(icon: Icons.home_repair_service_outlined, title: 'Purifier installed', date: p.installedOn, last: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => _remove(context),
            style: TextButton.styleFrom(foregroundColor: DF.ink400),
            child: const Text('Remove this purifier'),
          ),
        ),
      ],
    );
  }

  Future<void> _markDone(BuildContext context) async {
    var on = DateTime.now();
    var filters = false;
    final ok = await showDFSheet<bool>(
      context,
      title: 'Service done',
      subtitle: 'Counts the next service from this date.',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateTile(
              label: 'Serviced on',
              value: on,
              onPick: (d) => set(() => on = d),
              first: p.installedOn,
            ),
            CheckboxListTile(
              value: filters,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: DF.primary600,
              title: const Text('Filters were changed too', style: TextStyle(fontSize: 14, color: DF.ink700)),
              onChanged: (v) => set(() => filters = v == true),
            ),
            const SizedBox(height: 10),
            PrimaryButton('Save', onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await PurifierStore.instance.markServiced(on, filterChanged: filters);
    HapticFeedback.mediumImpact();
    if (context.mounted) toast(context, 'Saved. Next service ${_day(PurifierStore.instance.current.value!.nextService)}.');
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this purifier?'),
        content: const Text('Its history and reminders are removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await PurifierStore.instance.remove();
  }
}

/// A ring showing how much of an interval is left.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.label, required this.left, required this.days, required this.date});
  final String label;
  final double left;
  final int days;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(left);
    return DFCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: left),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => CustomPaint(
                painter: _RingPainter(value: v, color: tone),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(v * 100).round()}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tone)),
                      const Text('left', style: TextStyle(fontSize: 11.5, color: DF.ink400)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DF.ink900)),
          const SizedBox(height: 2),
          Text(_due(days), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: days < 0 ? DF.danger : DF.ink500)),
          Text(_day(date), style: const TextStyle(fontSize: 11.5, color: DF.ink300)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(arc, 0, math.pi * 2, false,
        Paint()
          ..color = DF.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * value, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.icon, required this.title, required this.date, this.last = false});
  final IconData icon;
  final String title;
  final DateTime date;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: DF.line))),
      child: Row(
        children: [
          Icon(icon, color: DF.primary600, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: DF.ink700))),
          Text(_day(date), style: const TextStyle(fontSize: 13, color: DF.ink400)),
        ],
      ),
    );
  }
}

/// A date field that opens the phone's date picker.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onPick, this.first});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;
  final DateTime? first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value.isAfter(now) ? now : value,
                firstDate: first ?? DateTime(now.year - 15),
                lastDate: now,
              );
              if (picked != null) onPick(picked);
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(border: Border.all(color: DF.lineStrong), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 19, color: DF.ink400),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_day(value), style: const TextStyle(fontSize: 14.5, color: DF.ink900))),
                  const Icon(Icons.expand_more_rounded, color: DF.ink300),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adding or editing the purifier.
class PurifierForm extends StatefulWidget {
  const PurifierForm({super.key, this.existing});
  final Purifier? existing;

  @override
  State<PurifierForm> createState() => _PurifierFormState();
}

class _PurifierFormState extends State<PurifierForm> {
  static const brands = ['Doctor Fresh', 'Kent', 'Aquaguard', 'Pureit', 'Livpure', 'A. O. Smith', 'Other'];
  static const types = ['RO', 'RO + UV', 'RO + UV + UF', 'UV', 'UF'];

  late String brand;
  late String type;
  late DateTime installed;
  late DateTime serviced;
  late DateTime filters;
  late int serviceMonths;
  late int filterMonths;
  late bool reminders;
  final tds = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    final now = DateTime.now();
    brand = p?.brand ?? 'Doctor Fresh';
    type = p?.type ?? 'RO + UV';
    installed = p?.installedOn ?? now;
    serviced = p?.lastService ?? now;
    filters = p?.lastFilterChange ?? now;
    serviceMonths = p?.serviceMonths ?? 3;
    filterMonths = p?.filterMonths ?? 12;
    reminders = p?.reminders ?? true;
    if (p?.tds != null) tds.text = '${p!.tds}';
  }

  @override
  void dispose() {
    tds.dispose();
    super.dispose();
  }

  Widget _chips<T>(String label, List<T> options, T selected, String Function(T) name, ValueChanged<T> onPick) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DF.ink700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final o in options) DFChip(name(o), selected: o == selected, onTap: () => setState(() => onPick(o)))],
            ),
          ],
        ),
      );

  Future<void> _save() async {
    setState(() => saving = true);
    if (reminders) reminders = await Native.requestNotifications();
    final old = widget.existing;
    final p = Purifier(
      brand: brand,
      type: type,
      installedOn: installed,
      lastService: serviced.isBefore(installed) ? installed : serviced,
      lastFilterChange: filters.isBefore(installed) ? installed : filters,
      serviceMonths: serviceMonths,
      filterMonths: filterMonths,
      tds: int.tryParse(tds.text.trim()),
      reminders: reminders,
      log: old?.log,
    );
    await PurifierStore.instance.save(p);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: widget.existing == null ? 'Add my purifier' : 'Edit purifier',
      showCart: false,
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: PrimaryButton('Save', loading: saving, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          DFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _chips<String>('Brand', brands, brand, (b) => b, (b) => brand = b),
                _chips<String>('Type', types, type, (t) => t, (t) => type = t),
                _DateTile(label: 'Installed on', value: installed, onPick: (d) => setState(() => installed = d)),
                _DateTile(label: 'Last service', value: serviced, onPick: (d) => setState(() => serviced = d), first: installed),
                _DateTile(label: 'Filters last changed', value: filters, onPick: (d) => setState(() => filters = d), first: installed),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _chips<int>('Service every', const [3, 4, 6], serviceMonths, (m) => '$m months', (m) => serviceMonths = m),
                _chips<int>('Change filters every', const [6, 9, 12], filterMonths, (m) => '$m months', (m) => filterMonths = m),
                DFField(label: 'Input water TDS (optional)', controller: tds, digitsOnly: true, maxLength: 4, hint: 'e.g. 450', keyboard: TextInputType.number),
                SwitchListTile(
                  value: reminders,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: DF.primary600,
                  title: const Text('Remind me before it is due', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                  onChanged: (v) => setState(() => reminders = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
