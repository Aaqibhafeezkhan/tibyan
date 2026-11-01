import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Anonymous crash reports, sent to our own GlitchTip server
/// (errors.altibyan.app, Sentry-compatible).
///
/// Starts only when the user agreed (asked once, see [CrashConsent]) AND
/// the build carries a DSN (`--dart-define-from-file=~/.config/tibyan/
/// sentry.env`, which holds `SENTRY_DSN=...`; never committed).
///
/// No personal data: no user, no IP, no device name, no screenshots, no
/// view hierarchy, no request data, no tracing. Breadcrumbs keep only the
/// kind of step (navigation, app lifecycle), never URLs or payloads.
class CrashReporting {
  static const _dsn = String.fromEnvironment('SENTRY_DSN');

  /// Where the build goes: `beta` (GitHub), `testflight`, `production`
  /// (App Store / Play). Set with `--dart-define=TIBYAN_CHANNEL=...`;
  /// release builds without it count as production.
  static const channel = String.fromEnvironment(
    'TIBYAN_CHANNEL',
    defaultValue: kReleaseMode ? 'production' : 'debug',
  );

  static bool _running = false;

  static bool get isAvailable => _dsn.isNotEmpty;

  /// Pre-builds (TestFlight, GitHub beta) suggest «agree» in the consent
  /// sheet; the store build leaves both choices equal.
  static bool get isPrerelease => channel != 'production';

  static Future<void> apply({required bool optIn}) async {
    if (!isAvailable) return;
    if (optIn && !_running) {
      final info = await PackageInfo.fromPlatform();
      await SentryFlutter.init((options) {
        options.dsn = _dsn;
        options.environment = channel;
        options.release = 'app.tibyan@${info.version}+${info.buildNumber}';
        options.dist = info.buildNumber;
        configure(options);
      });
      _running = true;
    } else if (!optIn && _running) {
      await Sentry.close();
      _running = false;
    }
  }

  /// The privacy and native settings, apart from [apply] so tests can
  /// check them.
  @visibleForTesting
  static void configure(SentryFlutterOptions options) {
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
    options.attachStacktrace = true;
    options.enableAutoPerformanceTracing = false;
    options.tracesSampleRate = 0;
    // Native crashes, hangs and the OS killing the app.
    options.enableNativeCrashHandling = true;
    options.enableWatchdogTerminationTracking = true; // iOS/macOS OOM
    options.enableAppHangTracking = true; // iOS/macOS
    options.anrEnabled = true; // Android
    options.enableNdkScopeSync = true; // Android NDK crashes
    options.enableAutoNativeBreadcrumbs = true;
    options.beforeSend = (event, hint) => scrub(event);
    options.beforeBreadcrumb = (crumb, hint) => scrubBreadcrumb(crumb);
  }

  /// Removes anything that could point to a person.
  @visibleForTesting
  static SentryEvent scrub(SentryEvent event) {
    event.user = null;
    event.request = null;
    event.serverName = null;
    final device = event.contexts.device;
    if (device != null) device.name = null;
    event.breadcrumbs = event.breadcrumbs
        ?.map(scrubBreadcrumb)
        .whereType<Breadcrumb>()
        .toList();
    return event;
  }

  /// Keeps the step's kind and time; drops URLs, payloads and free text
  /// for network and user-input crumbs.
  @visibleForTesting
  static Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb) {
    if (crumb == null) return null;
    final type = crumb.type ?? '';
    final category = crumb.category ?? '';
    if (type == 'http' || category.startsWith('http')) {
      crumb.data = null;
      crumb.message = null;
    }
    if (type == 'user' || category.startsWith('ui.')) {
      crumb.message = null;
      crumb.data = null;
    }
    return crumb;
  }

  static void debugLog(Object message) {
    if (kDebugMode) debugPrint('[crash] $message');
  }
}
