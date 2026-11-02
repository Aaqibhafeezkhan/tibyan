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
    numeralsFamily: ['assets/fonts/ofl/tibyannumerals/TibyanNumerals-Bold.ttf'],
  };

  late TextStyle body;
  late TextStyle mushafBody;
  late ThemeData plexTheme;

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
    final theme = buildTheme(
      style: registry.byId(registry.defaultStyleId),
      mode: ThemeModeId.light,
      uiFont: UiFont.changa,
    );
    plexTheme = buildTheme(
      style: registry.byId(registry.defaultStyleId),
      mode: ThemeModeId.light,
      uiFont: UiFont.plex,
    );
    body = theme.textTheme.bodyMedium!.copyWith(fontSize: 40);
    mushafBody = withMushafFonts(
      theme,
      UiFont.changa,
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

  test('the theme puts the bold numerals font ahead of Changa', () {
    expect(body.fontFamily, numeralsFamily);
    expect(body.fontFamilyFallback?.first, 'Changa');
    for (final f in UiFont.values) {
      expect(uiFallback(f).first, f.family);
    }
  });

  testWidgets('a Text on a non-mushaf screen resolves to the numerals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: plexTheme,
        home: const Scaffold(body: Text('٥٠/٠')),
      ),
    );
    final style = DefaultTextStyle.of(tester.element(find.text('٥٠/٠'))).style;
    expect(style.fontFamily, numeralsFamily);
    expect(style.fontFamilyFallback?.first, 'IBMPlexSansArabic');
  });

  test('the numerals font holds one face, and it is bold', () {
    final bytes = File(
      'assets/fonts/ofl/tibyannumerals/TibyanNumerals-Bold.ttf',
    ).readAsBytesSync();
    // OS/2 usWeightClass: the face is Bold (700) whatever weight is asked.
    final data = ByteData.sublistView(bytes);
    final tables = data.getUint16(4);
    for (var i = 0; i < tables; i++) {
      final at = 12 + i * 16;
      if (String.fromCharCodes(bytes.sublist(at, at + 4)) == 'OS/2') {
        expect(data.getUint16(data.getUint32(at + 8) + 4), 700);
        return;
      }
    }
    fail('no OS/2 table');
  });

  for (final number in ['٢٣', '١٢٣٤٥٦٧٨٩٠', '604', '۲۳', '٠/٥٠', '٪٥']) {
    test('$number is drawn in the bold numerals, not Changa', () {
      final themed = width(number, body);
      final light = body.copyWith(fontWeight: FontWeight.w300);
      expect(themed, closeTo(width(number, only(numeralsFamily)), .01));
      expect(width(number, light), closeTo(themed, .01));
      expect(themed, isNot(closeTo(width(number, only('Changa')), .01)));
    });
  }

  test('the mushaf keeps its digits font', () {
    expect(mushafBody.fontFamily, digitsFamily);
    expect(mushafBody.fontFamilyFallback?.first, 'Changa');
    const n = '١٢٣٤٥٦٧٨٩٠';
    expect(width(n, mushafBody), closeTo(width(n, only(digitsFamily)), .01));
  });

  test('letters around the numbers stay in Changa', () {
    const words = 'سورة الفاتحة آيات';
    expect(width(words, body), closeTo(width(words, only('Changa')), .01));
  });
}
