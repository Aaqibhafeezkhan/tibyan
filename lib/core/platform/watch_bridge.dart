import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sends what the watch shows (today's portion from the khatma widget
/// keys, the current dhikr from the tasbih widget keys) to the paired
/// watch: WatchConnectivity on iOS, the Wearable Data Layer on Android
/// (docs/WATCH.md). Counts made on the watch come back as tasbih pending
/// counts (see `TasbihPlatform.takePending`).
///
/// Where there is no watch side (macOS, tests, an app without the native
/// part) it does nothing.
class WatchBridge {
  const WatchBridge._();

  static const _channel = MethodChannel('app.tibyan/watch');

  static bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Merges [entries] into what the watch has and sends it.
  static Future<void> push(Map<String, String> entries) async {
    if (!_mobile || entries.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('push', entries);
    } on MissingPluginException {
      // No watch side in this build.
    } on PlatformException {
      // No paired watch, or the watch app is not installed.
    }
  }
}
