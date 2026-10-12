import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/contrast.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/features/share_image/share_document.dart';
import 'package:tibyan/features/share_image/share_palette.dart';

void main() {
  for (final style in InterfaceStyle.values) {
    for (final night in [false, true]) {
      test('${style.name} ${night ? 'night' : 'day'}: readable pictures', () {
        final p = sharePaletteOf(UiLook.of(style, night: night));
        expect(contrastRatio(p.ink, p.paper), greaterThanOrEqualTo(7));
        expect(contrastRatio(p.label, p.paper), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.divine, p.paper), greaterThanOrEqualTo(4.5));
        expect(p.dark, night);
      });
    }
  }

  test('the original colours stay available', () {
    expect(SharePalette.brand.paper, ShareBrand.paper);
    expect(SharePalette.brand.ink, ShareBrand.ink);
    expect(SharePalette.brand.dark, isFalse);
  });
}
