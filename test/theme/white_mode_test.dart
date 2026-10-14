import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';

/// «فاتح» (cream paper) and «أبيض زاهي» (pure white) must look clearly
/// different, in every interface style and on the mushaf page.
void main() {
  const white = Color(0xFFFFFFFF);

  /// Distance of a colour from pure white, summed over its channels.
  double tint(Color c) => (1 - c.r) + (1 - c.g) + (1 - c.b);

  for (final style in InterfaceStyle.values) {
    test('${style.name}: white grounds are pure white, light is cream', () {
      final light = UiLook.of(style, night: false);
      final bright = UiLook.of(style, night: false, white: true);
      for (final c in [bright.bg, bright.surface, bright.row]) {
        expect(c, white);
      }
      expect(bright.isWhite, isTrue);
      expect(light.isWhite, isFalse);
      // Cream: warm (red above blue) and visibly off white.
      expect(light.bg.r, greaterThan(light.bg.b));
      expect(tint(light.bg), greaterThan(.06));
      // Hairlines are neutral grey on white.
      expect((bright.line.r - bright.line.b).abs(), lessThan(.02));
    });

    test('${style.name}: white is ignored at night', () {
      expect(
        UiLook.of(style, night: true, white: true).bg,
        UiLook.of(style, night: true).bg,
      );
    });
  }

  final index = jsonDecode(
    File('assets/themes/index.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final id in List<String>.from(index['styles'] as List)) {
    test('$id: the light paper is cream, the white paper is white', () {
      final style = TibyanStyle.fromJson(
        jsonDecode(File('assets/themes/$id.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final light = style.modes[ThemeModeId.light]!;
      final bright = style.modes[ThemeModeId.white]!;
      expect(bright.paper, white);
      expect(bright.bg, white);
      expect(light.paper, isNot(white));
      expect(light.paper.r, greaterThan(light.paper.b));
      expect(tint(light.paper), greaterThan(.03));
    });
  }
}
