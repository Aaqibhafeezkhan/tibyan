import 'package:flutter/material.dart';

import '../theme/interface_style.dart';

/// Font family of KFGQPC's surah names (QCF4_QBSML, the surah-header
/// font of the 1441 Madina mushaf), shipped unmodified.
const surahNameFamily = 'QCF4_QBSML';

/// The text that draws surah [surah] (1–114) in [surahNameFamily]: one
/// private-use codepoint per surah from U+F100, each glyph the whole
/// «سورة …» title. Codepoints above U+F171 are other artwork.
String surahNameGlyphs(int surah) {
  assert(surah >= 1 && surah <= 114);
  return String.fromCharCode(0xF100 + surah - 1);
}

/// A surah's title («سورة …») in KFGQPC's surah-name calligraphy, read
/// out by screen readers as [name].
class SurahNameText extends StatelessWidget {
  const SurahNameText({
    super.key,
    required this.surah,
    required this.name,
    this.size = 28,
    this.color,
    this.height = 1.5,
  });

  final int surah;
  final String name;
  final double size;
  final Color? color;

  /// Line height: the glyphs reach well below the baseline.
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    child: ExcludeSemantics(
      child: Text(
        surahNameGlyphs(surah),
        maxLines: 1,
        softWrap: false,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: surahNameFamily,
          fontSize: size,
          height: height,
          color: color ?? context.look.ink,
        ),
      ),
    ),
  );
}
