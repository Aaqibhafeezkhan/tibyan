import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Not a test: draws the «what's new» sheet in Arabic and English, at its
/// opening height and scrolled to its end, into
/// `$WHATS_NEW_OUT/whats_new_<lang>_<n>.png`. Runs only with
/// RENDER_WHATS_NEW=1.
void main() {
  final run = Platform.environment['RENDER_WHATS_NEW'] == '1';
  final outPath = Platform.environment['WHATS_NEW_OUT'] ?? 'build/whats_new';

  testWidgets('render what\'s new', (tester) async {
    await tester.runAsync(() async {
      final manifest = jsonDecode(
        await rootBundle.loadString('FontManifest.json'),
      ) as List<dynamic>;
      for (final f in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(f['family'] as String);
        for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(Uri.decodeFull(a['asset'] as String)));
        }
        await loader.load();
      }
    });
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    final out = Directory(outPath)..createSync(recursive: true);
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    const host = Key('host');

    for (final lang in ['ar', 'en']) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(
              style: registry.byId('zakhrafa'),
              mode: ThemeModeId.light,
              uiFont: UiFont.plex,
              interfaceStyle: defaultInterfaceStyle,
            ),
            home: const Scaffold(
              body: LookTheme(child: SizedBox.expand(key: host)),
            ),
          ),
        ),
      );
      unawaited(showWhatsNew(tester.element(find.byKey(host))));
      await tester.pumpAndSettle();
      Future<void> grab(int n) async {
        final object =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bytes = (await tester.runAsync(() async {
          final image = await object.toImage(pixelRatio: 3);
          final d = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return d!.buffer.asUint8List();
        }))!;
        File('${out.path}/whats_new_${lang}_$n.png').writeAsBytesSync(bytes);
      }

      await grab(1);
      await tester.drag(
        find.byKey(const Key('whatsNewList')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('whatsNewList')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      await grab(2);
      await tester.drag(
        find.byKey(const Key('whatsNewList')),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      await grab(3);
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: !run);
}
