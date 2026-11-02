import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The store this build is for: `huawei` for Huawei AppGallery (built with
/// `--dart-define=TIBYAN_STORE=huawei`), `play` otherwise (Google Play,
/// App Store, GitHub). See docs/HUAWEI.md.
const appStore = String.fromEnvironment('TIBYAN_STORE', defaultValue: 'play');

/// The Huawei AppGallery build: no Google Play services, so Google Drive
/// sync, the Play review sheet and the Wear OS watch are off.
const isHuaweiBuild = appStore == 'huawei';

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
