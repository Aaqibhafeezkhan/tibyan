// Makes sample recitation reels on the device and prints their paths:
//
//   flutter test integration_test/share_video_test.dart -d macos
//
// Each finished file is printed as «REEL:<path>», then as base64 lines
// «MP4:<name>:<chunk>» for the host to join.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tibyan/app.dart';
import 'package:tibyan/features/share_video/share_video_screen.dart';
import 'package:tibyan/main.dart' as app;

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recitation reels', (t) async {
    SharedPreferences.setMockInitialValues({
      'settings.onboardingDone': true,
      'settings.mode': 'light',
      'settings.defaultsRev': 1,
      // The page look whose frame the reels take (--dart-define=REEL_STYLE).
      'settings.style': const String.fromEnvironment(
        'REEL_STYLE',
        defaultValue: 'zakhrafa',
      ),
    });
    unawaited(app.main());
    while (find.byType(TibyanApp).evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await pumpFor(t, const Duration(seconds: 3));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);

    // (surah, from, to, reciter): words lit (Husary), a mid-surah range.
    for (final (surah, from, to, reciter) in [
      (112, 1, 4, 2),
      (2, 255, 255, 1),
    ]) {
      String? out;
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => ShareVideoScreen(
              surah: surah,
              from: from,
              to: to,
              reciterId: reciter,
              onFinished: (p) => out = p,
            ),
          ),
        ),
      );
      await pumpFor(t, const Duration(seconds: 4));
      await t.tap(find.byIcon(Icons.movie_creation_outlined));
      final end = DateTime.now().add(const Duration(minutes: 8));
      while (out == null && DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(out, isNotNull);
      // ignore: avoid_print
      print('REEL:$out');
      // The file itself, for a host that cannot read the app's container.
      final b64 = base64Encode(File(out!).readAsBytesSync());
      final name = out!.split('/').last;
      for (var i = 0; i < b64.length; i += 4000) {
        // ignore: avoid_print
        print('MP4:$name:${b64.substring(i, (i + 4000).clamp(0, b64.length))}');
        if (i % 400000 == 0) await Future<void>.delayed(Duration.zero);
      }
      nav.pop();
      await pumpFor(t, const Duration(seconds: 1));
    }
  });
}
