import 'package:flutter/material.dart';

/// The website's design tokens (app/globals.css), one for one.
class DF {
  // primary
  static const primary50 = Color(0xFFF0F8FD);
  static const primary100 = Color(0xFFDFF0FB);
  static const primary200 = Color(0xFFBFE3F6);
  static const primary300 = Color(0xFF66C1EC);
  static const primary400 = Color(0xFF26A6E3);
  static const primary500 = Color(0xFF0095DC);
  static const primary600 = Color(0xFF0095DC);
  static const primary700 = Color(0xFF0078B4);
  static const primary800 = Color(0xFF00608F);
  static const primary900 = Color(0xFF063B4C);

  // ink (text)
  static const ink900 = Color(0xFF063B4C);
  static const ink800 = Color(0xFF0A4A5E);
  static const ink700 = Color(0xFF18343D);
  static const ink500 = Color(0xFF4A6470);
  static const ink400 = Color(0xFF5D7178);
  static const ink300 = Color(0xFF9DB3BC);

  // surfaces and lines
  /// The app's page background: white cards sit on it.
  static const canvas = Color(0xFFF3F6F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3FAFD);
  static const surfaceTint = Color(0xFFEEF7FD);
  static const line = Color(0xFFD9EAF0);
  static const lineStrong = Color(0xFFC2DCE6);

  // status
  static const success = Color(0xFF0A7A50);
  static const danger = Color(0xFFD92D20);
  static const warning = Color(0xFFDC9B06);

  // one-off colours the components use
  static const whatsapp = Color(0xFF25D366);
  static const star = Color(0xFFF5A524);
  static const save = Color(0xFF0078B4); // savings read in the brand blue
  static const saveBg = Color(0xFFF0F8FD);
  static const discountBg = Color(0xFFF0F8FD);
  static const stage = Color(0xFFF4F7F9);
  static const cardBorder = Color(0xFFE6ECF0);
  static const tileBg = Color(0xFFF5F5F5);
  static const heroBorder = Color(0xFFE6EAEE);
  static const tileSub = Color(0xFF7A8790);
  static const flameText = Color(0xFFC2410C);
  static const flameBg = Color(0xFFFFF7ED);
  static const flameBorder = Color(0xFFFED7AA);

  static const productShadow = [
    BoxShadow(color: Color(0x0D0F172A), spreadRadius: 1, blurRadius: 0),
    BoxShadow(color: Color(0x240F172A), offset: Offset(0, 6), blurRadius: 18, spreadRadius: -10),
  ];
  static const panelShadow = [
    BoxShadow(color: Color(0x14101828), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(color: Color(0x2E101828), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -6),
  ];

  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink900, height: 1.25, letterSpacing: -0.2);
  static const h2 = TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: ink900, height: 1.25, letterSpacing: -0.2);
  static const body = TextStyle(fontSize: 15, color: ink700, height: 1.6);
  static const muted = TextStyle(fontSize: 14, color: ink400, height: 1.5);
  static const eyebrow = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.7, color: primary700);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary600,
        primary: primary600,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: canvas,
      fontFamily: null, // Inter on the web; the platform sans here (no bundled font files).
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink700, displayColor: ink900),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(color: ink400, fontSize: 14.5),
        hintStyle: const TextStyle(color: ink300, fontSize: 14.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: lineStrong)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: lineStrong)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary500, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: danger)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: ink900),
    );
  }
}
