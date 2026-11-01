// A test entrypoint, never part of a release build (only reachable with
// `-t integration_test/crash_report_probe.dart`): checks that crash
// reports arrive in GlitchTip through the app's own CrashReporting setup.
//
//   flutter run -d <device> -t integration_test/crash_report_probe.dart \
//     --dart-define-from-file=$HOME/.config/tibyan/sentry.env \
//     --dart-define=TIBYAN_CHANNEL=debug --dart-define=PROBE=<mode>
//
// Modes:
//   dart    (default) consent «agree»: one handled + one uncaught Dart error.
//   native  consent «agree»: crashes natively on the first launch; launch
//           again (same mode) and the crash report is sent then.
//   optout  consent «no»: tries to report; nothing must arrive.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tibyan/core/crash/crash_reporting.dart';

const _mode = String.fromEnvironment('PROBE', defaultValue: 'dart');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stamp = DateTime.now().toUtc().toIso8601String();
  final os = Platform.operatingSystem;
  var status = '';
  if (!CrashReporting.isAvailable) {
    status = 'No SENTRY_DSN in this build.';
  } else if (_mode == 'optout') {
    await CrashReporting.apply(optIn: false);
    // Without consent the SDK is never started, so this goes nowhere.
    await Sentry.captureException(
      StateError('crash-report probe (opt-out, must not arrive) $os $stamp'),
    );
    status = 'Opt-out probe $stamp: nothing sent';
  } else if (_mode == 'native') {
    // ignore: avoid_print
    print('[crash-probe] native mode: starting SDK');
    await CrashReporting.apply(optIn: true);
    // ignore: avoid_print
    print('[crash-probe] SDK started');
    final marker = File('${Directory.systemTemp.path}/crash_probe_native');
    if (marker.existsSync()) {
      marker.deleteSync();
      status = 'Relaunched after native crash: report sent on start';
    } else {
      marker.createSync(recursive: true);
      // Time to detach a debugger: native crashes are not recorded while
      // one is attached.
      // ignore: avoid_print
      print('[crash-probe] native crash in 30s');
      await Future<void>.delayed(const Duration(seconds: 30));
      // ignore: avoid_print
      print('[crash-probe] native crash now');
      await SentryFlutter.nativeCrash();
    }
  } else {
    await CrashReporting.apply(optIn: true);
    try {
      throw StateError('crash-report probe (handled) $os $stamp');
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
    }
    Timer.run(
      () => throw StateError('crash-report probe (uncaught) $os $stamp'),
    );
    status = 'Sent probe $os $stamp';
  }
  // ignore: avoid_print
  print('[crash-probe] $status');
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(status))),
    ),
  );
}
