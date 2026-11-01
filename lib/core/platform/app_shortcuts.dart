import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the voice assistants open: «وردي اليومي», «متابعة القراءة» and a
/// surah. Each is an existing `tibyan://` link, so it goes through the same
/// routing as a widget or a verse link (main.dart `open`).
enum AppShortcut {
  /// Today's portion of the khatma being read (the reader link).
  dailyWird('wird'),

  /// Where reading stopped (the widget's «تابع»).
  continueReading('continue');

  const AppShortcut(this.key);
  final String key;

  Uri get link => switch (this) {
    AppShortcut.dailyWird => Uri.parse('tibyan://reader'),
    AppShortcut.continueReading => Uri.parse('tibyan://action/continue'),
  };
}

/// The link that opens surah [n] (at its first verse, in the edition
/// being read).
Uri surahShortcutLink(int n) => Uri(
  scheme: 'tibyan',
  host: 'verse',
  queryParameters: {'s': '$n', 'a': '1'},
);

/// Google Assistant's «open app feature» (`actions.intent.OPEN_APP_FEATURE`,
/// res/xml/shortcuts.xml) arrives as `tibyan://action/feature?name=<x>`:
/// the shortcut's id when it matched one, otherwise the words heard. The
/// link it stands for, or null when [uri] is not one or names nothing known.
Uri? assistantFeatureLink(Uri? uri) {
  if (uri == null || uri.scheme != 'tibyan' || uri.host != 'action') {
    return null;
  }
  if (uri.pathSegments.firstOrNull != 'feature') return null;
  final name = (uri.queryParameters['name'] ?? '').trim().toLowerCase();
  if (name.isEmpty) return null;
  for (final s in AppShortcut.values) {
    if (name == s.key) return s.link;
  }
  bool has(List<String> words) => words.any(name.contains);
  if (has(const ['wird', 'ورد', 'portion', 'khatma', 'ختم'])) {
    return AppShortcut.dailyWird.link;
  }
  if (has(const ['continue', 'resume', 'تابع', 'متابعة', 'أكمل', 'اكمل'])) {
    return AppShortcut.continueReading.link;
  }
  return null;
}

/// iOS App Shortcuts (Siri, Spotlight; ios/Runner/AppShortcuts.swift)
/// through `app.tibyan/shortcuts`: the app hands it the surah names it
/// already has (for «open surah …»), and it hands back the link of the
/// shortcut that was run.
class AppShortcutsChannel {
  AppShortcutsChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.tibyan/shortcuts');

  final MethodChannel _channel;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Listens for shortcuts run from now on, and opens one that launched
  /// the app; [surahs] are `(number, Arabic name, English name)`.
  Future<void> attach({
    required void Function(Uri link) open,
    required Future<List<(int, String, String)>> Function() surahs,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        final link = Uri.tryParse(call.arguments as String);
        if (link != null) open(link);
      }
      return null;
    });
    try {
      final pending = await _channel.invokeMethod<String>('ready');
      final link = pending == null ? null : Uri.tryParse(pending);
      if (link != null) open(link);
      final list = await surahs();
      await _channel.invokeMethod<void>('setSurahs', [
        for (final (n, ar, en) in list) {'n': n, 'ar': ar, 'en': en},
      ]);
    } on MissingPluginException {
      // An older build or a test: no shortcuts.
    }
  }
}
