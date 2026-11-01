import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/interface_style.dart';

/// Night and black must read apart: the black mode is true OLED black with
/// dimmer ink, the night mode keeps tinted, lifted grounds.
void main() {
  test('night and black chrome differ in every interface style', () {
    for (final style in InterfaceStyle.values) {
      final night = UiLook.of(style, night: true);
      final black = UiLook.of(style, night: true, black: true);
      expect(black.bg, const Color(0xFF000000), reason: style.name);
      expect(night.bg, isNot(black.bg), reason: style.name);
      expect(night.surface, isNot(black.surface), reason: style.name);
      expect(
        black.ink.computeLuminance(),
        lessThan(night.ink.computeLuminance()),
        reason: style.name,
      );
    }
  });

  test('black flag is ignored outside night', () {
    final light = UiLook.of(InterfaceStyle.values.first, night: false);
    final lightBlack = UiLook.of(
      InterfaceStyle.values.first,
      night: false,
      black: true,
    );
    expect(lightBlack.bg, light.bg);
  });

  test('theme tokens: black paper is pure black, night is lifted', () {
    final index = jsonDecode(
      File('assets/themes/index.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final id in (index['styles'] as List).cast<String>()) {
      final d = jsonDecode(
        File('assets/themes/$id.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final modes = d['modes'] as Map<String, dynamic>;
      final night = modes['night'] as Map<String, dynamic>;
      final black = modes['black'] as Map<String, dynamic>;
      expect(black['bg'], '#000000', reason: id);
      expect(black['paper'], '#000000', reason: id);
      Color c(String h) =>
          Color(int.parse('FF${h.substring(1, 7)}', radix: 16));
      expect(
        c(night['paper'] as String).computeLuminance(),
        greaterThan(0.01),
        reason: '$id night paper should be visibly lifted',
      );
      expect(night['ink'], isNot(black['ink']), reason: id);
    }
  });
}
