import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Whether the settings show the link to the device's accessibility
/// settings: Android and macOS only. iOS has no public link to that page
/// (only the app's own page), so the link is hidden there (owner, 4b).
bool get canOpenSystemAccessibility =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);

const _channel = MethodChannel('app.tibyan/settings');

/// Opens the device's accessibility settings: the Accessibility page on
/// Android and macOS; on iOS (no public link to it) the app's own page in
/// Settings. False where it could not.
Future<bool> openSystemAccessibility() async {
  try {
    if (!kIsWeb && Platform.isMacOS) {
      return await launchUrl(
        Uri.parse(
          'x-apple.systempreferences:com.apple.preference.universalaccess',
        ),
      );
    }
    return await _channel.invokeMethod<bool>('openAccessibilitySettings') ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
