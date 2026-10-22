import 'dart:convert';
import 'dart:io';

/// A small key/value store kept as one JSON file in the app's private folder —
/// what the website keeps in localStorage (cart, service cart, pin code) and
/// the session cookie.
///
/// The app folder is found without a plugin: the system temp folder is the
/// app's own cache folder on Android (/data/user/0/<app>/cache) and its tmp
/// folder on iOS (<container>/tmp), so its parent is private to the app.
class Store {
  Store._();
  static final Store instance = Store._();

  final Map<String, dynamic> _data = {};
  File? _file;

  Future<void> init() async {
    try {
      final root = Directory.systemTemp.parent;
      final dir = Directory('${root.path}${Platform.pathSeparator}df_store');
      if (!await dir.exists()) await dir.create(recursive: true);
      _file = File('${dir.path}${Platform.pathSeparator}store.json');
      if (await _file!.exists()) {
        final text = await _file!.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) _data.addAll(decoded);
      }
    } catch (_) {
      // An unreadable store starts empty rather than stopping the app.
    }
  }

  T? get<T>(String key) {
    final v = _data[key];
    return v is T ? v : null;
  }

  Future<void> set(String key, Object? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
    await _flush();
  }

  Future<void> remove(String key) => set(key, null);

  Future<void> _flush() async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode(_data), flush: true);
    } catch (_) {}
  }
}
