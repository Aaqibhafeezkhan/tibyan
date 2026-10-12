import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/contrast.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/tasmee/presentation/tasmee_style.dart';

/// The screens and overlays dressed with [LookTheme] take the interface
/// style's colours, and the tasmee's word states stay readable in each.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LookTheme gives the old colour readers the style\'s colours', () async {
    final registry = await ThemeRegistry.load(rootBundle);
    for (final style in InterfaceStyle.values) {
      for (final mode in [ThemeModeId.light, ThemeModeId.night]) {
        for (final elderly in [false, true]) {
          final base = buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: mode,
            uiFont: UiFont.plex,
            elderly: elderly,
            interfaceStyle: style,
          );
          final dressed = LookTheme.of(base);
          final look = dressed.extension<UiLook>()!;
          final t = dressed.extension<TibyanTokens>()!.colors;
          final tag = '${style.name} ${mode.name} elderly=$elderly';
          expect(t.paper, look.surface, reason: tag);
          expect(t.ink, look.ink, reason: tag);
          expect(t.control, look.control, reason: tag);
          expect(dressed.colorScheme.primary, look.control, reason: tag);
          expect(dressed.scaffoldBackgroundColor, look.bg, reason: tag);
          expect(
            contrastRatio(t.accentFg, t.accent),
            greaterThanOrEqualTo(4.5),
          );
          // Dressing twice changes nothing.
          final again = LookTheme.of(dressed).extension<TibyanTokens>()!;
          expect(again.colors.paper, t.paper);

          final c = TasmeeStateColors.of(mode, t);
          for (final (name, colour) in [
            ('wrong', c.wrong),
            ('skipped', c.skipped),
            ('corrected', c.corrected),
            ('hint', c.hint),
          ]) {
            for (final ground in [t.paper, t.bg]) {
              expect(
                contrastRatio(colour, ground),
                greaterThanOrEqualTo(4.5),
                reason: '$tag $name',
              );
            }
          }
          // Each state keeps its own colour.
          expect({c.wrong, c.skipped, c.corrected, c.hint}.length, 4);
        }
      }
    }
  });

  test('no arrow is mirrored twice', () {
    // Material's chevrons and arrows mirror themselves in right-to-left
    // text: choosing the other one for Arabic pointed them inward.
    final twice = RegExp(
      r'(rtl|TextDirection\.rtl)\s*\?\s*Icons\.(chevron|arrow|keyboard_arrow)',
    );
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (twice.hasMatch(f.readAsStringSync())) found.add(f.path);
    }
    expect(found, isEmpty);
  });

  test('the hifz test\'s «next verse» arrow follows the language', () {
    // keyboard_double_arrow_left does not mirror itself: the code picks
    // left for Arabic and right for English.
    final src = File('lib/features/mushaf/presentation/mushaf_screen_hifz.dart')
        .readAsStringSync();
    expect(Icons.keyboard_double_arrow_left.matchTextDirection, isFalse);
    expect(src, contains('Icons.keyboard_double_arrow_right'));
    expect(src, contains('TextDirection.ltr'));
  });
}
