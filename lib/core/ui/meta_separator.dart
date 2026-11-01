// The separator between pieces of metadata («الآية ٨٤ ✶ صفحة ٣٠٣»): a
// small gold eight-pointed star instead of a middle dot, which reads as
// the Arabic-Indic zero «٠» next to digits («٨٤ · ٣٠٣» looks like «٨٤٠»).
//
// Strings keep « · » as the separator token (in the ARB files and where
// code joins metadata with [metaSep]); [MetaText] draws each token as the
// star, and [plainMeta] turns it into « – » where only plain text works
// (notifications, share text, platform widgets).
import 'package:flutter/material.dart';

import '../theme/interface_style.dart';
import '../theme/ornaments.dart';

/// The separator token between metadata pieces in strings.
const metaSep = ' · ';

final _token = RegExp(r'\s*[·•∙⋅・]\s*');

/// [text] with every separator token as « – », for plain-text contexts.
String plainMeta(String text) => text.replaceAll(_token, ' – ');

/// [text] as a screen reader should hear it: each separator a pause
/// (a comma), never «dot» or «zero».
String spokenMeta(String text) =>
    text.replaceAll(_token, RegExp(r'[؀-ۿ]').hasMatch(text) ? '، ' : ', ');

/// Paints an eight-pointed star (the two-square star of the rub' sign's
/// outline, from [starPath]) filling its box.
class _MetaStarPainter extends CustomPainter {
  const _MetaStarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    starPath(size.center(Offset.zero), size.shortestSide / 2),
    Paint()
      ..color = color
      ..isAntiAlias = true,
  );

  @override
  bool shouldRepaint(_MetaStarPainter o) => o.color != color;
}

/// The small gold star between metadata pieces, about 0.55 of [fontSize]
/// with even space on both sides. Hidden from screen readers.
class MetaSeparator extends StatelessWidget {
  const MetaSeparator({super.key, this.fontSize = 14, this.color});

  final double fontSize;

  /// Defaults to the interface style's text gold.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final star = fontSize * 0.55;
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.35),
        child: CustomPaint(
          size: Size.square(star),
          painter: _MetaStarPainter(color ?? context.look.goldText),
        ),
      ),
    );
  }

  /// The star as an inline span, centred on the line.
  static InlineSpan span({double fontSize = 14, Color? color}) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: MetaSeparator(fontSize: fontSize, color: color),
  );
}

/// [text] split at its separator tokens, with [MetaSeparator] stars
/// between the pieces.
InlineSpan metaSpan(String text, {TextStyle? style, double fontSize = 14}) {
  final parts = text.split(_token);
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0) MetaSeparator.span(fontSize: fontSize),
        TextSpan(text: parts[i]),
      ],
    ],
  );
}

/// A drop-in [Text] for metadata lines: separator tokens in [data] are
/// drawn as small gold stars, and read out as pauses.
class MetaText extends StatelessWidget {
  const MetaText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textScaler,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    if (!_token.hasMatch(data)) {
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        semanticsLabel: semanticsLabel,
        textScaler: textScaler,
      );
    }
    final size = DefaultTextStyle.of(context).style.merge(style).fontSize ?? 14;
    return Text.rich(
      metaSpan(data, style: style, fontSize: size),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel ?? spokenMeta(data),
      textScaler: textScaler,
    );
  }
}
