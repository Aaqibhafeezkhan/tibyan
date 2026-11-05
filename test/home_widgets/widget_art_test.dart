import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/home_widgets/widget_art.dart';
import 'package:tibyan/features/home_widgets/widget_look_sync.dart';
import 'package:tibyan/features/khatma/services/home_widget_sync.dart';
import 'package:tibyan/l10n/app_localizations.dart';

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('variants: every style light and night, and the app\'s white', () {
    final base = widgetVariants(InterfaceStyle.handasi, ThemeModeId.night);
    expect(base, hasLength(6));
    final white = widgetVariants(InterfaceStyle.layli, ThemeModeId.white);
    expect(white, hasLength(7));
    expect(white.last, (InterfaceStyle.layli, ThemeModeId.white));
    expect(
      widgetArtKey(
        WidgetFace.verse,
        WidgetShape.medium,
        InterfaceStyle.makhtuta,
        ThemeModeId.light,
      ),
      'wl_verse_medium_makhtuta_light',
    );
  });

  test('specs: slots inside the picture, buttons at the reading end', () {
    for (final style in InterfaceStyle.values) {
      for (final mode in ThemeModeId.values) {
        final look = widgetLook(style, mode);
        for (final face in WidgetFace.values) {
          for (final shape in WidgetShape.values) {
            for (final l in [ar, en]) {
              final art = buildWidgetArt(face, shape, look, l);
              final spec = jsonDecode(art.spec('x.png')) as Map;
              for (final s in spec['slots'] as List) {
                final m = s as Map;
                final x = m['x'] as double, y = m['y'] as double;
                final w = m['w'] as double, h = m['h'] as double;
                expect(x >= 0 && y >= 0 && w > 0 && h > 0, isTrue);
                expect(x + w <= 1.0001 && y + h <= 1.0001, isTrue);
              }
              expect(art.taps, isNotEmpty);
            }
          }
        }
      }
    }
    // The verse reads right to left even in English; its «استمع» is at
    // the end, the left.
    final verse = buildWidgetArt(
      WidgetFace.verse,
      WidgetShape.medium,
      widgetLook(InterfaceStyle.handasi, ThemeModeId.light),
      en,
    );
    expect(verse.rtl, isTrue);
    expect(verse.taps['button']!.center.dx, lessThan(182));
    // The khatma in English: left to right, the button on the right.
    final khatma = buildWidgetArt(
      WidgetFace.khatma,
      WidgetShape.medium,
      widgetLook(InterfaceStyle.layli, ThemeModeId.night),
      en,
    );
    expect(khatma.rtl, isFalse);
    expect(khatma.taps['button']!.center.dx, greaterThan(182));
    // The manuscript's verse has its star for the verse number.
    final manuscript = buildWidgetArt(
      WidgetFace.verse,
      WidgetShape.medium,
      widgetLook(InterfaceStyle.makhtuta, ThemeModeId.light),
      ar,
    );
    expect(manuscript.slots.map((s) => s.id), containsAll(['num', 'surah']));
  });

  testWidgets('every picture lays out without overflow', (tester) async {
    for (final style in InterfaceStyle.values) {
      for (final mode in const [ThemeModeId.light, ThemeModeId.black]) {
        for (final face in WidgetFace.values) {
          for (final shape in WidgetShape.values) {
            final art = buildWidgetArt(face, shape, widgetLook(style, mode), ar);
            await tester.pumpWidget(Center(child: art.art));
            expect(tester.takeException(), isNull);
          }
        }
      }
    }
  });

  test('follow: draws once per look and language, writes wl_app', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final widgets = NoHomeWidget();
    var drawn = 0;
    final sync = WidgetLookSync(
      widgets,
      prefs,
      painter: (_, _, _) async {
        drawn++;
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final pictures = 6 * WidgetFace.values.length * WidgetShape.values.length;
    await sync.follow(
      style: InterfaceStyle.handasi,
      mode: ThemeModeId.light,
      l: ar,
    );
    expect(drawn, pictures);
    expect(widgets.looks['wl_app'], 'handasi_light');
    final spec =
        jsonDecode(widgets.looks['wl_tasbih_small_layli_night']!) as Map;
    expect(spec['file'], 'wl_tasbih_small_layli_night_png.png');
    expect(widgets.files, contains('wl_tasbih_small_layli_night_png.png'));

    // Another light/night look: only wl_app changes.
    await sync.follow(
      style: InterfaceStyle.layli,
      mode: ThemeModeId.night,
      l: ar,
    );
    expect(drawn, pictures);
    expect(widgets.looks['wl_app'], 'layli_night');

    // «أبيض زاهي» needs its own pictures, and a new language all again.
    await sync.follow(
      style: InterfaceStyle.layli,
      mode: ThemeModeId.white,
      l: ar,
    );
    expect(drawn, pictures * 2 + pictures ~/ 6);
    expect(widgets.looks, contains('wl_verse_small_layli_white'));
  });
}
