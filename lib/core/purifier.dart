import 'package:flutter/foundation.dart';

import 'native.dart';
import 'storage.dart';

/// The customer's own water purifier, kept on the phone: when it was
/// installed, serviced and had its filters changed, and what is due next.
/// Nothing here goes to the server — it is the app's own tracker, with local
/// reminders when a service or a filter change comes due.
class Purifier {
  Purifier({
    required this.brand,
    required this.type,
    required this.installedOn,
    required this.lastService,
    required this.lastFilterChange,
    this.serviceMonths = 3,
    this.filterMonths = 12,
    this.tds,
    this.reminders = true,
    List<DateTime>? log,
  }) : log = log ?? [];

  String brand;
  String type;
  DateTime installedOn;
  DateTime lastService;
  DateTime lastFilterChange;
  int serviceMonths;
  int filterMonths;
  int? tds;
  bool reminders;

  /// Services done, newest first.
  List<DateTime> log;

  DateTime get nextService => _addMonths(lastService, serviceMonths);
  DateTime get nextFilterChange => _addMonths(lastFilterChange, filterMonths);

  /// Days until (positive) or past (negative) the date.
  static int daysUntil(DateTime when) {
    return _dateOnly(when).difference(_dateOnly(DateTime.now())).inDays;
  }

  /// How much of the service interval is left, 0…1.
  double get serviceLeft => _left(lastService, nextService);
  double get filterLeft => _left(lastFilterChange, nextFilterChange);

  static double _left(DateTime from, DateTime to) {
    final total = to.difference(from).inDays;
    if (total <= 0) return 0;
    return (daysUntil(to) / total).clamp(0.0, 1.0);
  }

  static DateTime _addMonths(DateTime d, int months) {
    final m = d.month - 1 + months;
    final year = d.year + m ~/ 12;
    final month = m % 12 + 1;
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > last ? last : d.day);
  }

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'type': type,
        'installedOn': installedOn.toIso8601String(),
        'lastService': lastService.toIso8601String(),
        'lastFilterChange': lastFilterChange.toIso8601String(),
        'serviceMonths': serviceMonths,
        'filterMonths': filterMonths,
        'tds': tds,
        'reminders': reminders,
        'log': log.map((d) => d.toIso8601String()).toList(),
      };

  static Purifier? fromJson(Map? j) {
    if (j == null) return null;
    DateTime? date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    final installed = date(j['installedOn']);
    if (installed == null) return null;
    return Purifier(
      brand: '${j['brand'] ?? ''}',
      type: '${j['type'] ?? 'RO + UV'}',
      installedOn: installed,
      lastService: date(j['lastService']) ?? installed,
      lastFilterChange: date(j['lastFilterChange']) ?? installed,
      serviceMonths: j['serviceMonths'] is int ? j['serviceMonths'] as int : 3,
      filterMonths: j['filterMonths'] is int ? j['filterMonths'] as int : 12,
      tds: j['tds'] is int ? j['tds'] as int : null,
      reminders: j['reminders'] != false,
      log: [for (final v in (j['log'] as List? ?? const [])) if (date(v) != null) date(v)!],
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The saved purifier, listened to by the home card and the purifier screen.
class PurifierStore {
  PurifierStore._();
  static final PurifierStore instance = PurifierStore._();

  static const _key = 'my_purifier';
  static const _serviceReminder = 7001;
  static const _filterReminder = 7002;

  /// Where a tapped reminder takes the customer (see AppTabs / router).
  static const route = 'app://my-purifier';

  final ValueNotifier<Purifier?> current = ValueNotifier(null);

  void load() {
    current.value = Purifier.fromJson(Store.instance.get<Map>(_key));
  }

  Future<void> save(Purifier p) async {
    await Store.instance.set(_key, p.toJson());
    // A fresh object, so listeners rebuild.
    current.value = Purifier.fromJson(p.toJson());
    await _reschedule(p);
  }

  Future<void> remove() async {
    await Store.instance.remove(_key);
    current.value = null;
    await Native.cancel(_serviceReminder);
    await Native.cancel(_filterReminder);
  }

  Future<void> markServiced(DateTime on, {bool filterChanged = false}) async {
    final p = current.value;
    if (p == null) return;
    p.lastService = on;
    if (filterChanged) p.lastFilterChange = on;
    p.log = [on, ...p.log]..sort((a, b) => b.compareTo(a));
    await save(p);
  }

  /// Reminders at 10 am, three days before each date (or on the day itself
  /// when that is already past).
  Future<void> _reschedule(Purifier p) async {
    await Native.cancel(_serviceReminder);
    await Native.cancel(_filterReminder);
    if (!p.reminders) return;

    DateTime at(DateTime due) {
      final early = DateTime(due.year, due.month, due.day, 10).subtract(const Duration(days: 3));
      final now = DateTime.now();
      if (early.isAfter(now)) return early;
      final onDay = DateTime(due.year, due.month, due.day, 10);
      return onDay.isAfter(now) ? onDay : now.add(const Duration(hours: 1));
    }

    final name = p.brand.isEmpty ? 'your purifier' : 'your ${p.brand} purifier';
    await Native.schedule(
      id: _serviceReminder,
      at: at(p.nextService),
      title: 'Service due for $name',
      body: 'A routine service keeps the water clean and the filters lasting longer. Book a technician in two taps.',
      route: route,
    );
    await Native.schedule(
      id: _filterReminder,
      at: at(p.nextFilterChange),
      title: 'Time to change the filters',
      body: 'The filters in $name are due for a change. Check the filter health and book it from the app.',
      route: route,
    );
  }
}
