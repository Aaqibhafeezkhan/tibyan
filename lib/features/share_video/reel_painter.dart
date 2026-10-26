import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/theme/ornaments.dart' show starPath;
import '../mushaf/data/divine_names.dart';
import 'reel_timeline.dart';

/// The reel's colours (tools/video/ayah_reel_mushaf.html).
abstract final class ReelColors {
  static const teal = Color(0xFF0F6660);
  static const tealLo = Color(0xFF0A4F4A);
  static const tealDeep = Color(0xFF083F3B);
  static const gold = Color(0xFFD9B266);
  static const cream = Color(0xFFF6F1E8);
  static const ink = Color(0xFF211C19);
  static const divine = Color(0xFFC62828);
  static const lineFill = Color(0xFFEFE6D8);
  static const lineEdge = Color(0xFFC4A885);
  static const wordFill = Color(0xFFDEC9B3);
  static const wordEdge = Color(0xFFB79069);
}

/// One verse of a reel: its stored text, verbatim from content.db.
class ReelVerse {
  const ReelVerse({required this.number, required this.displayText});

  final int number;

  /// `ayah.display_text`: the words, then the verse-number glyph.
  final String displayText;

  /// The words as the app numbers them (the hizb sign is not one).
  List<String> get words => [
    for (final w in _body.split(_space))
      if (w.isNotEmpty && w != '۞') w,
  ];

  int get _split => displayText.lastIndexOf(_space);
  String get _body => displayText.substring(0, _split);
}

final _space = RegExp('[  ]');

/// Everything a reel shows besides its timing. Texts other than the
/// verses are the app's own strings (Arabic).
class ReelContent {
  const ReelContent({
    required this.surah,
    required this.verses,
    required this.heading,
    required this.range,
    required this.voice,
    required this.credit,
    required this.join,
    required this.url,
    required this.stores,
    required this.frame,
    required this.logo,
    required this.logoSize,
    required this.paper,
    this.banner,
  });

  final int surah;
  final List<ReelVerse> verses;
  final String heading, range, voice, credit, join, url, stores;

  /// The mushaf page's frame, as the reader's theme draws it.
  final ui.Image frame;

  /// The surah's banner, when the first verse opens the surah.
  final ui.Image? banner;

  /// The Tibyan calligraphy, drawn in cream.
  final ui.Picture logo;

  /// The page's paper, as the reader's theme has it.
  final Color paper;

  /// The logo picture's own size.
  final Size logoSize;
}

/// The size the reel is designed at; smaller reels scale it down.
const reelDesign = Size(1080, 1920);

const _page = Rect.fromLTWH(136, 384, 808, 1350);

/// Room inside the page's frame, as a share of the page (the frame's band
/// is 36 of 404 logical points wide).
const _frameInset = 36 / 404;

/// A verse laid out: its paragraph, and each word's character range.
class _VerseText {
  _VerseText(this.painter, this.words);
  final TextPainter painter;
  final List<TextRange> words;
}

/// Draws the frames of a reel.
class ReelPainter {
  ReelPainter(this.content, this.timeline) {
    _layout();
  }

  final ReelContent content;
  final ReelTimeline timeline;

  late Rect _textBox;
  Rect? _bannerBox;
  late List<List<int>> _pages;
  late List<_VerseText> _verses;

  /// When each page after the first comes in.
  List<double> get pageStarts => [
    for (final p in _pages.skip(1))
      timeline.cues.firstWhere((c) => c.ayah == p.first).start,
  ];

  int get pageCount => _pages.length;

  static String _glyph(int surah) => String.fromCharCode(0xF100 + surah - 1);

  void _layout() {
    final inset = _page.width * _frameInset;
    final inner = _page.deflate(inset + 8);
    final banner = content.banner;
    if (banner != null) {
      final h = inner.width * banner.height / banner.width;
      _bannerBox = Rect.fromLTWH(inner.left, inner.top + 6, inner.width, h);
      _textBox = Rect.fromLTRB(
        inner.left + 8,
        _bannerBox!.bottom + 12,
        inner.right - 8,
        inner.bottom - 8,
      );
    } else {
      _textBox = inner.deflate(8);
    }
    // One page with every verse at the biggest size that fits; else pages
    // of whole verses at one size.
    final all = [for (var i = 0; i < content.verses.length; i++) i];
    for (var size = 110.0; size >= 70; size -= 2) {
      final v = _build(size);
      if (_fits(v, all)) {
        _verses = v;
        _pages = [all];
        return;
      }
    }
    for (var size = 84.0; size >= 30; size -= 2) {
      final v = _build(size);
      final pages = <List<int>>[];
      var cur = <int>[];
      var ok = true;
      for (final i in all) {
        if (_fits(v, [...cur, i])) {
          cur.add(i);
        } else if (cur.isEmpty) {
          ok = false;
          break;
        } else {
          pages.add(cur);
          cur = [i];
          if (!_fits(v, cur)) {
            ok = false;
            break;
          }
        }
      }
      if (ok) {
        _verses = v;
        _pages = [...pages, cur];
        return;
      }
    }
    // Never reached for real verses; the smallest size, one per page.
    _verses = _build(30);
    _pages = [
      for (final i in all) [i],
    ];
  }

  bool _fits(List<_VerseText> v, List<int> page) {
    var h = 0.0;
    for (final i in page) {
      h += v[i].painter.height;
    }
    return h <= _textBox.height;
  }

  List<_VerseText> _build(double size) => [
    for (final v in content.verses) _verseText(v, size),
  ];

  /// The verse's stored text as it is, split only to know where each word
  /// is and to colour the divine name.
  _VerseText _verseText(ReelVerse v, double size) {
    final style = TextStyle(
      fontFamily: 'UthmanicHafs',
      fontSize: size,
      height: 1.9,
      color: ReelColors.ink,
    );
    final text = v.displayText;
    final spans = <TextSpan>[];
    final words = <TextRange>[];
    final split = text.lastIndexOf(_space);
    var i = 0;
    for (final m in _space.allMatches(text)) {
      if (m.start > i) _word(text, i, m.start, split, spans, words, style);
      spans.add(TextSpan(text: m.group(0)));
      i = m.end;
    }
    if (i < text.length) {
      _word(text, i, text.length, split, spans, words, style);
    }
    final painter = TextPainter(
      text: TextSpan(style: style, children: spans),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: _textBox.width - 20);
    return _VerseText(painter, words);
  }

  static void _word(
    String text,
    int from,
    int to,
    int split,
    List<TextSpan> spans,
    List<TextRange> words,
    TextStyle style,
  ) {
    final w = text.substring(from, to);
    final isWord = from < split && w != '۞';
    if (isWord) words.add(TextRange(start: from, end: to));
    spans.add(
      TextSpan(
        text: w,
        style: isWord && isDivineName(w)
            ? const TextStyle(color: ReelColors.divine)
            : null,
      ),
    );
  }

  TextPainter _line(
    String text,
    double size, {
    Color color = ReelColors.cream,
    String family = 'TibyanDigits',
    FontWeight weight = FontWeight.w400,
    TextDirection dir = TextDirection.rtl,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontFamilyFallback: const ['Changa'],
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.3,
      ),
    ),
    textDirection: dir,
    textAlign: TextAlign.center,
  )..layout();

  ui.Picture? _background, _intro, _outro, _head;

  /// Draws the frame of [s] on [canvas], [size] pixels.
  void paint(Canvas canvas, Size size, FrameState s) {
    canvas.save();
    canvas.scale(size.width / reelDesign.width);
    canvas.drawPicture(_background ??= _record(_drawBackground));
    if (s.intro > 0) {
      _faded(canvas, s.intro, () {
        canvas.drawPicture(_intro ??= _record(_drawIntro));
      });
    }
    if (s.body > 0) {
      _faded(canvas, s.body, () {
        canvas.drawPicture(_head ??= _record(_drawHead));
        _drawPages(canvas, s);
      });
    }
    if (s.outro > 0) {
      _faded(canvas, s.outro, () {
        canvas.drawPicture(_outro ??= _record(_drawOutro));
      });
    }
    canvas.restore();
  }

  static void _faded(Canvas canvas, int alpha, void Function() draw) {
    if (alpha >= 255) {
      draw();
      return;
    }
    canvas.saveLayer(null, Paint()..color = Color.fromARGB(alpha, 0, 0, 0));
    draw();
    canvas.restore();
  }

  static ui.Picture _record(void Function(Canvas) draw) {
    final r = ui.PictureRecorder();
    draw(Canvas(r));
    return r.endRecording();
  }

  void _drawBackground(Canvas c) {
    final full = Offset.zero & reelDesign;
    c.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(reelDesign.width / 2, reelDesign.height * .42),
          reelDesign.height * .7,
          const [ReelColors.teal, ReelColors.tealLo, ReelColors.tealDeep],
          const [0, .62, 1],
        ),
    );
    // The app's girih lattice (GirihPainter).
    const cell = 118.0;
    final p = Paint()
      ..color = ReelColors.cream.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var y = 0.0; y < reelDesign.height + cell; y += cell) {
      for (var x = 0.0; x < reelDesign.width + cell; x += cell) {
        c.drawPath(starPath(Offset(x, y), cell * .5, inner: .72), p);
        c.drawPath(
          starPath(
            Offset(x + cell / 2, y + cell / 2),
            cell * .22,
            points: 4,
            inner: .45,
          ),
          p,
        );
      }
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ReelColors.gold.withValues(alpha: .35);
    c.drawRRect(
      RRect.fromRectAndRadius(full.deflate(56), const Radius.circular(28)),
      edge,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(full.deflate(68), const Radius.circular(20)),
      edge
        ..strokeWidth = 1
        ..color = ReelColors.gold.withValues(alpha: .18),
    );
  }

  /// The logo, [width] wide, its top centre at [top].
  void _logo(Canvas c, double top, double width) {
    final logo = content.logo;
    final bounds = content.logoSize;
    final k = width / bounds.width;
    c.save();
    c.translate((reelDesign.width - width) / 2, top);
    c.scale(k);
    c.saveLayer(
      Offset.zero & bounds,
      Paint()
        ..colorFilter = const ColorFilter.mode(
          ReelColors.cream,
          BlendMode.srcIn,
        ),
    );
    c.drawPicture(logo);
    c.restore();
    c.restore();
  }

  double _logoHeight(double width) =>
      width * content.logoSize.height / content.logoSize.width;

  /// Draws [items] (painters and fixed gaps) as a centred column from
  /// [top]; returns the bottom.
  double _column(Canvas c, double top, List<Object> items) {
    var y = top;
    for (final it in items) {
      switch (it) {
        case double gap:
          y += gap;
        case TextPainter p:
          p.paint(c, Offset((reelDesign.width - p.width) / 2, y));
          y += p.height;
        case (double _, double h, void Function(Canvas, double) draw):
          draw(c, y);
          y += h;
      }
    }
    return y;
  }

  double _height(List<Object> items) {
    var h = 0.0;
    for (final it in items) {
      h += switch (it) {
        double gap => gap,
        TextPainter p => p.height,
        (double _, double h, Object _) => h,
        _ => 0,
      };
    }
    return h;
  }

  (double, double, void Function(Canvas, double)) _logoItem(double width) =>
      (width, _logoHeight(width), (c, y) => _logo(c, y, width));

  (double, double, void Function(Canvas, double)) _rule() => (
    260,
    2,
    (c, y) => c.drawRect(
      Rect.fromLTWH((reelDesign.width - 260) / 2, y, 260, 2),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset((reelDesign.width - 260) / 2, y),
          Offset((reelDesign.width + 260) / 2, y),
          [
            ReelColors.gold.withValues(alpha: 0),
            ReelColors.gold,
            ReelColors.gold.withValues(alpha: 0),
          ],
          const [0, .5, 1],
        ),
    ),
  );

  void _drawIntro(Canvas c) {
    final items = <Object>[
      _logoItem(420),
      50.0,
      _line(
        content.heading,
        96,
        color: ReelColors.gold,
        family: 'Changa',
        weight: FontWeight.w700,
      ),
      10.0,
      _line(_glyph(content.surah), 120, family: 'QCF4_QBSML'),
      6.0,
      _line(content.range, 46, color: ReelColors.gold),
      40.0,
      _rule(),
      54.0,
      _line(content.voice, 44, color: ReelColors.cream.withValues(alpha: .9)),
    ];
    _column(c, (reelDesign.height - _height(items)) / 2, items);
  }

  void _drawOutro(Canvas c) {
    final items = <Object>[
      _logoItem(360),
      70.0,
      _line(content.join, 120, family: 'Changa', weight: FontWeight.w700),
      10.0,
      _line(
        content.url,
        64,
        color: ReelColors.gold,
        family: 'Changa',
        weight: FontWeight.w500,
        dir: TextDirection.ltr,
      ),
      40.0,
      _rule(),
      56.0,
      _line(
        content.stores,
        36,
        color: ReelColors.cream.withValues(alpha: .85),
        family: 'Changa',
        dir: TextDirection.ltr,
      ),
    ];
    _column(c, (reelDesign.height - _height(items)) / 2, items);
  }

  void _drawHead(Canvas c) {
    // Logo, heading, then the surah's name and the verses.
    final name = _line(_glyph(content.surah), 62, family: 'QCF4_QBSML');
    final range = _line(content.range, 40, color: ReelColors.gold);
    final y = _column(c, 92, [
      _logoItem(110),
      4.0,
      _line(
        content.heading,
        60,
        color: ReelColors.gold,
        family: 'Changa',
        weight: FontWeight.w700,
      ),
    ]);
    final h = math.max(name.height, range.height);
    final w = name.width + 14 + range.width;
    final x = (reelDesign.width - w) / 2;
    // Right to left: the name, then the verses.
    name.paint(c, Offset(x + w - name.width, y - 6 + (h - name.height) / 2));
    range.paint(c, Offset(x, y - 6 + (h - range.height) / 2));
    final credit = _line(
      content.credit,
      30,
      color: ReelColors.cream.withValues(alpha: .72),
    );
    credit.paint(
      c,
      Offset(
        (reelDesign.width - credit.width) / 2,
        reelDesign.height - 120 - credit.height,
      ),
    );
    // The page: shadow, the frame's art, the banner.
    final rr = RRect.fromRectAndRadius(_page, const Radius.circular(32));
    c.drawRRect(
      rr.shift(const Offset(0, 30)),
      Paint()
        ..color = const Color(0x73000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
    c.save();
    c.clipRRect(rr);
    c.drawRect(_page, Paint()..color = content.paper);
    paintImage(
      canvas: c,
      rect: _page,
      image: content.frame,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );
    c.restore();
    if (content.banner case final b?) {
      paintImage(
        canvas: c,
        rect: _bannerBox!,
        image: b,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
  }

  void _drawPages(Canvas c, FrameState s) {
    final cue = s.cue == null ? null : timeline.cues[s.cue!];
    for (var k = 0; k < _pages.length; k++) {
      final a = k < s.pages.length ? s.pages[k] : 0;
      if (a == 0) continue;
      _faded(c, a, () => _drawPage(c, _pages[k], cue));
    }
  }

  void _drawPage(Canvas c, List<int> page, ReelCue? cue) {
    var h = 0.0;
    for (final i in page) {
      h += _verses[i].painter.height;
    }
    var y = _textBox.top + (_textBox.height - h) / 2;
    for (final i in page) {
      final v = _verses[i];
      final p = v.painter;
      final x = _textBox.left + (_textBox.width - p.width) / 2;
      if (cue != null && cue.ayah == i) {
        // The verse being recited, then its word.
        final block = Rect.fromLTWH(x - 10, y, p.width + 20, p.height);
        final rr = RRect.fromRectAndRadius(block, const Radius.circular(12));
        c.drawRRect(rr, Paint()..color = ReelColors.lineFill);
        c.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ReelColors.lineEdge,
        );
        final w = cue.word;
        if (w != null && w >= 1 && w <= v.words.length) {
          final r = v.words[w - 1];
          final boxes = p.getBoxesForSelection(
            TextSelection(baseOffset: r.start, extentOffset: r.end),
          );
          for (final b in boxes) {
            final rect = b.toRect().shift(Offset(x, y)).inflate(4);
            // The word's ink is about the middle of its line box.
            final wr = RRect.fromRectAndRadius(
              Rect.fromLTRB(
                rect.left,
                rect.top + rect.height * .12,
                rect.right,
                rect.bottom - rect.height * .08,
              ),
              const Radius.circular(9),
            );
            c.drawRRect(wr, Paint()..color = ReelColors.wordFill);
            c.drawRRect(
              wr,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = ReelColors.wordEdge,
            );
          }
        }
      }
      p.paint(c, Offset(x, y));
      y += p.height;
    }
  }

  void dispose() {
    for (final p in [_background, _intro, _outro, _head]) {
      p?.dispose();
    }
    for (final v in _verses) {
      v.painter.dispose();
    }
  }
}
