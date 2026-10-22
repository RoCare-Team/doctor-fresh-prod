/// Where the app talks to. Every API the app calls lives on the website
/// itself (app/api/* in the Next.js project), so this is the only address.
///
/// For a local backend run the app with:
///   flutter run --dart-define=DF_BASE_URL=http://10.0.2.2:3000
class Config {
  static const String baseUrl = String.fromEnvironment(
    'DF_BASE_URL',
    defaultValue: 'https://www.doctorfresh.in',
  );

  static const String phone = '+91-9311587716';
  static const String phoneRaw = '+919311587716';
  static const String email = 'info@doctorfresh.in';
  static const String whatsapp = 'https://wa.me/919311587716';
  static const String whatsappHelp =
      'https://wa.me/919311587716?text=Hi%2C%20I%20need%20help%20choosing%20a%20water%20purifier%20%2F%20booking%20a%20service.';

  /// A site path ("/uploads/x.jpg") or an absolute address, made absolute.
  static String url(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }
}
