import 'package:flutter/painting.dart';

import '../../core/theme/contrast.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/theme_tokens.dart';
import 'share_document.dart';

/// The shared pictures in the reader's colours: the interface style's
/// paper and labels, and the mushaf page's own paper and ink when it is as
/// light (or as dark) as the style. The Quran text reaches 7:1 on the
/// paper and every label 4.5:1; ornaments keep the style's gold.
SharePalette sharePaletteOf(UiLook look, {ModeTokens? page}) {
  final pageFits =
      page != null && (page.paper.computeLuminance() < .18) == look.night;
  final paper = pageFits ? page.paper : (look.night ? look.bg : look.surface);
  final grounds = [paper];
  final ink = towardContrast(
    pageFits ? page.ink : look.ink,
    extremeAgainst(paper),
    grounds,
    7,
  );
  final label = towardContrast(
    look.isHandasi || look.isMakhtuta ? look.accent : look.goldText,
    ink,
    grounds,
    4.5,
  );
  final divine = towardContrast(
    look.night ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
    ink,
    grounds,
    4.5,
  );
  return SharePalette(
    paper: paper,
    ink: ink,
    label: label,
    gold: look.gold,
    goldPale: Color.alphaBlend(look.gold.withValues(alpha: .16), paper),
    divine: divine,
  );
}
