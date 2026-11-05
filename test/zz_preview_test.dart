import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/home_widgets/widget_art.dart';
import 'package:tibyan/l10n/app_localizations.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  testWidgets('preview', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    await _font('Changa', ['assets/fonts/ofl/changa/Changa[wght].ttf']);
    final mi = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    await _font('MaterialIcons', [mi]);
    final out = Platform.environment['OUT'] ?? '/tmp/wlprev';
    final l = lookupAppLocalizations(Locale(Platform.environment['LANG_W'] ?? 'ar'));
    for (final style in InterfaceStyle.values) {
      for (final mode in [ThemeModeId.light, ThemeModeId.night]) {
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: Directionality(textDirection: TextDirection.ltr, child: ColoredBox(color: const Color(0xFF3A6A8A), child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in WidgetFace.values)
            for (final s in WidgetShape.values) buildWidgetArt(f, s, widgetLook(style, mode), l).art,
        ])))));
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1.5);
          final d = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/${style.name}_${mode.name}.png').writeAsBytesSync(d!.buffer.asUint8List());
        });
      }
    }
  });
}
