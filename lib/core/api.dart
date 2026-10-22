import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'config.dart';
import 'storage.dart';

/// What came back from the site: the decoded JSON (a map, or a list for the
/// feed endpoints), the HTTP status, and the error message the site sent.
class ApiResult {
  ApiResult(this.status, this.data, {this.networkError = false});

  final int status;
  final dynamic data;
  final bool networkError;

  bool get ok {
    if (networkError || status < 200 || status >= 300) return false;
    if (data is Map && data['ok'] == false) return false;
    return true;
  }

  Map<String, dynamic> get map => data is Map<String, dynamic> ? data as Map<String, dynamic> : <String, dynamic>{};
  List<dynamic> get list => data is List ? data as List : const [];

  /// `{ signIn: true }` on a 401 means the session is gone.
  bool get needsSignIn => status == 401 || map['signIn'] == true;

  String get error {
    if (networkError) return 'No internet connection. Please check and try again.';
    final e = map['error'];
    if (e is String && e.isNotEmpty) return e;
    return 'Something went wrong. Please try again.';
  }
}

/// The HTTP client for every call the app makes.
///
/// The site keeps the signed-in customer in an httpOnly cookie (`df_session`,
/// set by /api/auth/verify-otp) and recently viewed products in `df_recent`.
/// A browser sends them back on its own; here they are kept in [Store] and
/// attached to every request.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _cookieKey = 'cookies';
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..userAgent = 'DoctorFreshApp/1.0 (Flutter)';

  Map<String, String> get _cookies {
    final raw = Store.instance.get<Map>(_cookieKey);
    return raw == null ? {} : raw.map((k, v) => MapEntry('$k', '$v'));
  }

  bool get hasSession => (_cookies['df_session'] ?? '').isNotEmpty;

  Future<void> clearCookies() => Store.instance.remove(_cookieKey);

  /// The cookies as one header, for anything that must be fetched signed in.
  String get cookieHeader => _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  /// Read by hand rather than through `res.cookies`, which throws on values
  /// with characters Dart's cookie parser does not accept (`df_recent` holds
  /// a comma-separated list).
  Future<void> _keepCookies(HttpClientResponse res) async {
    final headers = res.headers[HttpHeaders.setCookieHeader];
    if (headers == null || headers.isEmpty) return;
    final jar = _cookies;
    for (final header in headers) {
      final parts = header.split(';');
      final first = parts.first;
      final eq = first.indexOf('=');
      if (eq <= 0) continue;
      final name = first.substring(0, eq).trim();
      final value = first.substring(eq + 1).trim();
      final attrs = parts.skip(1).map((p) => p.trim().toLowerCase());
      final expired = attrs.any((a) => a == 'max-age=0' || a.startsWith('max-age=-'));
      if (expired || value.isEmpty) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
    await Store.instance.set(_cookieKey, jar);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(Config.url(path));
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {
      ...base.queryParameters,
      for (final e in query.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    });
  }

  Future<ApiResult> get(String path, {Map<String, dynamic>? query}) => _send('GET', _uri(path, query));

  Future<ApiResult> post(String path, [Object? body]) => _send('POST', _uri(path), body: body);

  Future<ApiResult> patch(String path, [Object? body]) => _send('PATCH', _uri(path), body: body);

  Future<ApiResult> _send(String method, Uri uri, {Object? body}) async {
    try {
      final req = await _client.openUrl(method, uri).timeout(const Duration(seconds: 30));
      req.followRedirects = true;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final cookie = cookieHeader;
      if (cookie.isNotEmpty) req.headers.set(HttpHeaders.cookieHeader, cookie);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 60));
      await _keepCookies(res);
      final text = await res.transform(utf8.decoder).join();
      dynamic data;
      try {
        data = text.isEmpty ? null : jsonDecode(text);
      } catch (_) {
        data = {'ok': false, 'error': text.length < 200 ? text : 'Unexpected answer from the server.'};
      }
      return ApiResult(res.statusCode, data);
    } on SocketException {
      return ApiResult(0, null, networkError: true);
    } on TimeoutException {
      return ApiResult(0, null, networkError: true);
    } on HandshakeException {
      return ApiResult(0, null, networkError: true);
    } catch (e) {
      return ApiResult(0, {'ok': false, 'error': 'Something went wrong. Please try again.'});
    }
  }

  /// multipart/form-data, for the careers form (a CV upload).
  Future<ApiResult> multipart(
    String path, {
    required Map<String, String> fields,
    String? fileField,
    String? fileName,
    Uint8List? fileBytes,
    String? fileType,
  }) async {
    final boundary = '----df${DateTime.now().microsecondsSinceEpoch}';
    final out = BytesBuilder();
    void line(String s) => out.add(utf8.encode('$s\r\n'));
    fields.forEach((k, v) {
      line('--$boundary');
      line('Content-Disposition: form-data; name="$k"');
      line('');
      line(v);
    });
    if (fileField != null && fileBytes != null) {
      line('--$boundary');
      line('Content-Disposition: form-data; name="$fileField"; filename="${fileName ?? 'file'}"');
      line('Content-Type: ${fileType ?? 'application/octet-stream'}');
      line('');
      out.add(fileBytes);
      line('');
    }
    line('--$boundary--');

    try {
      final req = await _client.postUrl(_uri(path));
      req.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      final cookie = cookieHeader;
      if (cookie.isNotEmpty) req.headers.set(HttpHeaders.cookieHeader, cookie);
      req.add(out.takeBytes());
      final res = await req.close();
      await _keepCookies(res);
      final text = await res.transform(utf8.decoder).join();
      dynamic data;
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = {'ok': false};
      }
      return ApiResult(res.statusCode, data);
    } catch (_) {
      return ApiResult(0, null, networkError: true);
    }
  }

  /// Raw bytes (an invoice PDF), sent with the session cookie.
  Future<(int, Uint8List?)> bytes(String path) async {
    try {
      final req = await _client.getUrl(_uri(path));
      final cookie = cookieHeader;
      if (cookie.isNotEmpty) req.headers.set(HttpHeaders.cookieHeader, cookie);
      final res = await req.close();
      final builder = BytesBuilder();
      await for (final chunk in res) {
        builder.add(chunk);
      }
      return (res.statusCode, builder.takeBytes());
    } catch (_) {
      return (0, null);
    }
  }
}
