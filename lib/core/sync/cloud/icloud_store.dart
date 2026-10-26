import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cloud_store.dart';

/// The app's iCloud container (`iCloud.app.tibyan.tibyan`), through the
/// native channel `app.tibyan/icloud` (ios/Runner/AppDelegate.swift,
/// macos/Runner/MainFlutterWindow.swift): the sync files live in its
/// `Sync` folder, which the reader does not see in iCloud Drive.
///
/// A build without the iCloud capability has no container: the channel
/// then says so and sync is «not available in this version».
class ICloudStore implements CloudStore {
  ICloudStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.tibyan/icloud');

  final MethodChannel _channel;

  @override
  String get kind => 'icloud';

  @override
  Future<CloudUnavailable?> unavailable() async {
    try {
      final s = await _channel.invokeMethod<String>('status');
      return switch (s) {
        'available' => null,
        'noAccount' => CloudUnavailable.noAccount,
        _ => CloudUnavailable.notInThisBuild,
      };
    } on MissingPluginException {
      return CloudUnavailable.notInThisBuild;
    } on PlatformException catch (e) {
      debugPrint('icloud: $e');
      return CloudUnavailable.notInThisBuild;
    }
  }

  @override
  Future<bool> connect() async => await unavailable() == null;

  @override
  Future<Map<String, String>> readAll() async {
    final m = await _channel.invokeMapMethod<String, String>('readAll');
    return m ?? const {};
  }

  @override
  Future<void> write(String name, String content) =>
      _channel.invokeMethod('write', {'name': name, 'content': content});

  @override
  Future<void> deleteAll() => _channel.invokeMethod('deleteAll');

  @override
  Future<void> disconnect() async {}
}
