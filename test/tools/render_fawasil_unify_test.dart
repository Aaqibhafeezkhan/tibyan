import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/verse_services.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Not a test: draws the ayah tools panel with the real fonts at phone,
/// tablet and desktop widths, text scales 1.0 and 1.3 and elderly mode,
/// light and night, into `$FAWASIL_OUT/panel_*.png`. Runs only with
/// RENDER_FAWASIL=1.
void main() {
  final run = Platform.environment['RENDER_FAWASIL'] == '1';
  final outPath = Platform.environment['FAWASIL_OUT'] ?? 'build/fawasil';

  testWidgets(
    'render the ayah tools panel',
    (tester) async {
      await tester.runAsync(() async {
        final manifest = jsonDecode(
          await rootBundle.loadString('FontManifest.json'),
        ) as List<dynamic>;
        for (final f in manifest.cast<Map<String, dynamic>>()) {
          final loader = FontLoader(f['family'] as String);
          for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
            loader.addFont(
              rootBundle.load(Uri.decodeFull(a['asset'] as String)),
            );
          }
          await loader.load();
        }
      });
      final registry = (await tester.runAsync(
        () => ThemeRegistry.load(rootBundle),
      ))!;
      final out = Directory(outPath)..createSync(recursive: true);
      final boundary = GlobalKey();
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      for (final (w, h) in [(393.0, 852.0), (820.0, 1180.0), (1280.0, 800.0)]) {
        for (final (scale, elderly) in [
          (1.0, false),
          (1.3, false),
          (1.0, true),
        ]) {
          for (final mode in [ThemeModeId.light, ThemeModeId.night]) {
            await tester.binding.setSurfaceSize(Size(w, h));
            tester.view.devicePixelRatio = 2;
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  key: UniqueKey(),
                  debugShowCheckedModeBanner: false,
                  locale: const Locale('ar'),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: buildTheme(
                    style: registry.byId('zakhrafa'),
                    mode: mode,
                    uiFont: UiFont.plex,
                    elderly: elderly,
                    interfaceStyle: defaultInterfaceStyle,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        elderly ? elderlyTextScale : scale,
                      ),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        child: VerseServicesPanel(
                          verses: const [(surah: 2, ayah: 255)],
                          surahs: null,
                          onMark: (_) {},
                          onSaveToFasil: () {},
                          onClose: () {},
                          onMultiSelect: () {},
                          onTafsir: () {},
                          onListen: () {},
                          onWordStudy: () {},
                          onWordMeanings: () {},
                          onReflect: () {},
                          onCopy: () {},
                          onShareText: () {},
                          onShareImage: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final name =
                'panel_${w.toInt()}_${elderly ? 'elderly' : 'x$scale'}_${mode.name}';
            final object =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final png = (await tester.runAsync(() async {
              final image = await object.toImage(pixelRatio: 2);
              final d = await image.toByteData(format: ui.ImageByteFormat.png);
              image.dispose();
              return d!.buffer.asUint8List();
            }))!;
            File('${out.path}/$name.png').writeAsBytesSync(png);
          }
        }
      }
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
