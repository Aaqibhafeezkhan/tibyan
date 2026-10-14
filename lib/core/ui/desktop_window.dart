// The desktop window (macOS, Windows, Linux): a comfortable size the first
// time, a minimum below which the layouts stop fitting, and the size and
// place the reader left it at every time after.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'responsive.dart';

class DesktopWindow with WindowListener {
  DesktopWindow._(this._prefs);

  final SharedPreferences _prefs;
  Timer? _save;

  static const defaultSize = Size(1280, 820);
  static const minimumSize = Size(900, 640);

  static const _kBounds = 'window.bounds';
  static const _kMaximized = 'window.maximized';

  static Future<void> init(SharedPreferences prefs, {String? title}) async {
    if (!isDesktopPlatform) return;
    await windowManager.ensureInitialized();
    final saved = _read(prefs);
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: saved?.size ?? defaultSize,
        minimumSize: minimumSize,
        center: saved == null,
        title: title,
      ),
      () async {
        if (saved != null) await windowManager.setBounds(saved);
        if (prefs.getBool(_kMaximized) ?? false) {
          await windowManager.maximize();
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
    windowManager.addListener(DesktopWindow._(prefs));
  }

  /// The saved bounds, or null when there are none or they make no sense
  /// (smaller than the minimum, or far off any screen's origin).
  static Rect? _read(SharedPreferences prefs) {
    final v = prefs.getStringList(_kBounds);
    if (v == null || v.length != 4) return null;
    final n = v.map(double.tryParse).toList();
    if (n.contains(null)) return null;
    final r = Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!);
    if (r.width < minimumSize.width || r.height < minimumSize.height) {
      return null;
    }
    if (r.left < -r.width / 2 || r.top < -40) return null;
    return r;
  }

  void _later() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 500), () async {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen() ||
          await windowManager.isMinimized()) {
        return;
      }
      final r = await windowManager.getBounds();
      await _prefs.setStringList(_kBounds, [
        for (final x in [r.left, r.top, r.width, r.height]) x.toString(),
      ]);
    });
  }

  @override
  void onWindowResized() => _later();

  @override
  void onWindowMoved() => _later();

  @override
  void onWindowMaximize() => _prefs.setBool(_kMaximized, true);

  @override
  void onWindowUnmaximize() {
    _prefs.setBool(_kMaximized, false);
    _later();
  }
}
