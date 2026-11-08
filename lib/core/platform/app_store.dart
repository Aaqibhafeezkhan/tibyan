import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The store this build is for: `huawei` for Huawei AppGallery (built with
/// `--dart-define=TIBYAN_STORE=huawei`), `msstore` for the Microsoft Store
/// MSIX (`--dart-define=TIBYAN_STORE=msstore`), `play` otherwise (Google
/// Play, App Store, GitHub). See docs/HUAWEI.md and docs/RELEASE.md.
const appStore = String.fromEnvironment('TIBYAN_STORE', defaultValue: 'play');

/// The Huawei AppGallery build: no Google Play services, so Google Drive
/// sync, the Play review sheet and the Wear OS watch are off.
const isHuaweiBuild = appStore == 'huawei';

/// The Microsoft Store build: the Store delivers updates, so the in-app
/// Windows updater is off (Store policy).
const isMsStoreBuild = appStore == 'msstore';

/// Whether Google Play services can be used here. False in the Huawei
/// build, and on an Android phone without them (a Huawei phone with the
/// Play build sideloaded), so no Google call is made there.
class GoogleServices {
  const GoogleServices._();

  static const _channel = MethodChannel('app.tibyan/store');
  static Future<bool>? _available;

  static Future<bool> available() => _available ??= _check();

  static Future<bool> _check() async {
    if (isHuaweiBuild) return false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('gmsAvailable') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }
}
