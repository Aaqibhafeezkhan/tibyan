import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';

/// Changa's ٢ and ٣ read alike: under Changa every interface digit is drawn
/// in [digitsFamily], and every other letter still in Changa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fonts = {
    'Changa': ['assets/fonts/ofl/changa/Changa[wght].ttf'],
    digitsFamily: ['assets/fonts/ofl/tibyandigits/TibyanDigits-Regular.ttf'],
  };

  late TextStyle body;

  setUpAll(() async {
    for (final MapEntry(key: family, value: paths) in fonts.entries) {
      final loader = FontLoader(family);
      for (final p in paths) {
        loader.addFont(
          Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
        );
      }
      await loader.load();
    }
    final registry = await ThemeRegistry.load(rootBundle);
    body = buildTheme(
      style: registry.byId(registry.defaultStyleId),
      mode: ThemeModeId.light,
      uiFont: UiFont.changa,
    ).textTheme.bodyMedium!.copyWith(fontSize: 40);
  });

  double width(String text, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
    )..layout();
    return p.width;
  }

  TextStyle only(String family) =>
      body.copyWith(fontFamily: family, fontFamilyFallback: const []);

  test('the theme puts the digits font ahead of Changa', () {
    expect(body.fontFamily, digitsFamily);
    expect(body.fontFamilyFallback?.first, 'Changa');
    expect(UiFont.plex.textFamily, UiFont.plex.family);
  });

  for (final number in ['٢٣', '١٢٣٤٥٦٧٨٩٠', '604', '۲۳']) {
    test('$number is drawn in the digits font, not Changa', () {
      final themed = width(number, body);
      expect(themed, closeTo(width(number, only(digitsFamily)), .01));
      expect(themed, isNot(closeTo(width(number, only('Changa')), .01)));
    });
  }

  test('letters around the numbers stay in Changa', () {
    const words = 'سورة الفاتحة آيات';
    expect(width(words, body), closeTo(width(words, only('Changa')), .01));
  });
}
