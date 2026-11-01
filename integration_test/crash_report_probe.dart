// A test entrypoint, never part of a release build: it sends one handled
// exception and one uncaught error to GlitchTip, to check that reports
// arrive. Run on a simulator (debug):
//
//   flutter run -d <sim> -t integration_test/crash_report_probe.dart \
//     --dart-define-from-file=$HOME/.config/tibyan/sentry.env \
//     --dart-define=TIBYAN_CHANNEL=debug
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tibyan/core/crash/crash_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashReporting.apply(optIn: true);
  final stamp = DateTime.now().toUtc().toIso8601String();
  String status;
  if (!CrashReporting.isAvailable) {
    status = 'No SENTRY_DSN in this build.';
  } else {
    try {
      throw StateError('crash-report probe (handled) $stamp');
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
    }
    // Uncaught: goes through the SDK's zone / FlutterError hooks.
    Timer.run(() => throw StateError('crash-report probe (uncaught) $stamp'));
    status = 'Sent probe $stamp';
  }
  // ignore: avoid_print
  print('[crash-probe] $status');
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(status))),
    ),
  );
}
