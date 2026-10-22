import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'config.dart';

/// The few things only the phone itself can do — open a link in the browser,
/// dial, open WhatsApp, share, open a PDF, pick a file — through a platform
/// channel implemented in MainActivity.kt (Android) and AppDelegate.swift
/// (iOS). No plugin package is used.
class Native {
  static const _channel = MethodChannel('in.doctorfresh.app/native');

  /// Opens a web, tel:, mailto: or WhatsApp link outside the app. If the
  /// native side is missing, the link is copied so it is never lost.
  static Future<bool> open(String url, {BuildContext? context}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      if (ok == true) return true;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: url));
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: $url')));
    }
    return false;
  }

  static Future<void> call([String number = Config.phoneRaw]) => open('tel:$number');

  static Future<void> whatsapp([String url = Config.whatsappHelp]) => open(url);

  static Future<void> email([String to = Config.email]) => open('mailto:$to');

  /// The phone's share sheet; copies the link when there is none.
  static Future<void> share(String text, {BuildContext? context}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('share', {'text': text});
      if (ok == true) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: text));
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }

  /// Saves [bytes] to the app's cache and opens them in the phone's viewer.
  static Future<bool> openBytes(Uint8List bytes, String fileName, {String mime = 'application/pdf'}) async {
    try {
      final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      final ok = await _channel.invokeMethod<bool>('openFile', {'path': file.path, 'mime': mime});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads a signed-in file (an invoice) and opens it.
  static Future<String?> downloadAndOpen(String path, String fileName) async {
    final (status, data) = await Api.instance.bytes(path);
    if (status == 401) return 'Please sign in to download this.';
    if (status != 200 || data == null || data.isEmpty) return 'Could not download the file.';
    final opened = await openBytes(data, fileName);
    return opened ? null : 'No app found to open the PDF.';
  }

  /// Lets the customer pick a file (a CV). Returns null when cancelled.
  static Future<PickedFile?> pickFile() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('pickFile');
      if (res == null) return null;
      final path = res['path'] as String?;
      if (path == null) return null;
      final bytes = await File(path).readAsBytes();
      return PickedFile(name: '${res['name'] ?? 'file'}', mime: '${res['mime'] ?? 'application/octet-stream'}', bytes: bytes);
    } catch (_) {
      return null;
    }
  }

  /// The phone's position, asking for permission the first time.
  /// `{lat, lon}`, or `{error: 'denied' | 'off' | 'unavailable'}`.
  static Future<Map<String, dynamic>> location() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('location');
      return res ?? const {'error': 'unavailable'};
    } catch (_) {
      return const {'error': 'unavailable'};
    }
  }
}

class PickedFile {
  PickedFile({required this.name, required this.mime, required this.bytes});
  final String name;
  final String mime;
  final Uint8List bytes;
}
