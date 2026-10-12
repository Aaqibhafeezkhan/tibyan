// Design prototype only: three visual directions for Home, Index and
// Settings. Not wired into lib/. Rendered by render_redesign_test.dart.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class SurahRow {
  const SurahRow(
    this.id,
    this.nameAr,
    this.nameEn,
    this.meccan,
    this.ayahs,
    this.page,
    this.juz,
  );
  final int id;
  final String nameAr;
  final String nameEn;
  final bool meccan;
  final int ayahs;
  final int page;
  final int juz;
}

class JuzRow {
  const JuzRow(this.juz, this.surahAr, this.ayah, this.page);
  final int juz;
  final String surahAr;
  final int ayah;
  final int page;
}

class ProtoData {
  const ProtoData(this.surahs, this.juz);
  final List<SurahRow> surahs;
  final List<JuzRow> juz;
}

String ar(int n) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

const _ordinals = [
  'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', //
  'الثامن', 'التاسع', 'العاشر',
];

String juzName(int j) {
  if (j <= 10) return 'الجزء ${_ordinals[j - 1]}';
  if (j == 20) return 'الجزء العشرون';
  if (j == 30) return 'الجزء الثلاثون';
  return 'الجزء ${ar(j)}';
}

// ---------------------------------------------------------------------------
// Looks
// ---------------------------------------------------------------------------

enum Dir { makhtuta, handasi, layli }

class Look {
  const Look({
    required this.dir,
    required this.night,
    required this.bg,
    required this.surface,
    required this.row,
    required this.ink,
    required this.sub,
    required this.gold,
    required this.accent,
    required this.accent2,
    required this.frame,
    required this.onFrame,
    required this.nameFont,
    required this.headFont,
  });

  final Dir dir;
  final bool night;
  final Color bg, surface, row, ink, sub, gold, accent, accent2, frame;
  final Color onFrame;
  final String nameFont, headFont;
  static const ui = 'IBMPlexSansArabic';

  static Look of(Dir d, bool night) {
    switch (d) {
      case Dir.makhtuta:
        return night
            ? const Look(
                dir: Dir.makhtuta,
                night: true,
                bg: Color(0xFF16110D),
                surface: Color(0xFF221A13),
                row: Color(0xFF2A2018),
                ink: Color(0xFFF1E4CC),
                sub: Color(0xFFC2AE92),
                gold: Color(0xFFD6A94E),
                accent: Color(0xFFC98B5A),
                accent2: Color(0xFF6E9BD1),
                frame: Color(0xFF0C0806),
                onFrame: Color(0xFFE2B95E),
                nameFont: 'UthmanTahaNaskh',
                headFont: 'ArefRuqaa',
              )
            : const Look(
                dir: Dir.makhtuta,
                night: false,
                bg: Color(0xFFEFE2CB),
                surface: Color(0xFFF7EDDE),
                row: Color(0xFFF7EDDE),
                ink: Color(0xFF1E1915),
                sub: Color(0xFF6A5644),
                gold: Color(0xFFA9781F),
                accent: Color(0xFF7A4A26),
                accent2: Color(0xFF23466E),
                frame: Color(0xFF4A2B15),
                onFrame: Color(0xFFF0CF83),
                nameFont: 'UthmanTahaNaskh',
                headFont: 'ArefRuqaa',
              );
      case Dir.handasi:
        return night
            ? const Look(
                dir: Dir.handasi,
                night: true,
                bg: Color(0xFF0E1A1B),
                surface: Color(0xFF152627),
                row: Color(0xFF152627),
                ink: Color(0xFFE7EFEC),
                sub: Color(0xFF9DB6B1),
                gold: Color(0xFFD9B266),
                accent: Color(0xFF55BDB2),
                accent2: Color(0xFFE59A62),
                frame: Color(0xFF0A1314),
                onFrame: Color(0xFF55BDB2),
                nameFont: 'KFGQPCKufiExtended',
                headFont: 'KFGQPCKufiExtended',
              )
            : const Look(
                dir: Dir.handasi,
                night: false,
                bg: Color(0xFFF6F1E8),
                surface: Color(0xFFFFFCF6),
                row: Color(0xFFFFFCF6),
                ink: Color(0xFF1E1915),
                sub: Color(0xFF5E5A52),
                gold: Color(0xFF9A7428),
                accent: Color(0xFF0F6660),
                accent2: Color(0xFFB4561F),
                frame: Color(0xFF0F6660),
                onFrame: Color(0xFFFFFCF6),
                nameFont: 'KFGQPCKufiExtended',
                headFont: 'KFGQPCKufiExtended',
              );
      case Dir.layli:
        return night
            ? const Look(
                dir: Dir.layli,
                night: true,
                bg: Color(0xFF0B1424),
                surface: Color(0xFF13203A),
                row: Color(0xFF111D33),
                ink: Color(0xFFF3EAD6),
                sub: Color(0xFFAFB6C6),
                gold: Color(0xFFDDB665),
                accent: Color(0xFFDDB665),
                accent2: Color(0xFF4FA37C),
                frame: Color(0xFF070D18),
                onFrame: Color(0xFFDDB665),
                nameFont: 'ArefRuqaa',
                headFont: 'ArefRuqaa',
              )
            : const Look(
                dir: Dir.layli,
                night: false,
                bg: Color(0xFFF8F1E1),
                surface: Color(0xFFFFFAEE),
                row: Color(0xFFFFFAEE),
                ink: Color(0xFF14203A),
                sub: Color(0xFF545E73),
                gold: Color(0xFF9C7524),
                accent: Color(0xFF14203A),
                accent2: Color(0xFF2E7D5B),
                frame: Color(0xFF14203A),
                onFrame: Color(0xFFE6C47A),
                nameFont: 'ArefRuqaa',
                headFont: 'ArefRuqaa',
              );
    }
  }
}

class Ctx {
  const Ctx({
    required this.look,
    required this.data,
    this.english = false,
    this.elderly = false,
  });
  final Look look;
  final ProtoData data;
  final bool english;
  final bool elderly;
  String s(String a, String e) => english ? e : a;
  String n(int v) => english ? '$v' : ar(v);
  String get ui => english ? 'IBMPlexSans' : Look.ui;
}

TextStyle ts(
  Ctx c,
  double size,
  Color color, {
  String? font,
  FontWeight w = FontWeight.w400,
  double? h,
}) => TextStyle(
  fontFamily: font ?? c.ui,
  fontFamilyFallback: const ['IBMPlexSansArabic'],
  fontSize: size,
  color: color,
  fontWeight: w,
  height: h,
);

// ---------------------------------------------------------------------------
// Ornament painters (all original vector art)
// ---------------------------------------------------------------------------

Path starPath(Offset c, double r, {int points = 8, double inner = 0.765}) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final rr = i.isEven ? r : r * inner;
    final a = -math.pi / 2 + i * math.pi / points;
    final o = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// An 8-point star medallion holding a number.
class StarBadge extends StatelessWidget {
  const StarBadge({
    super.key,
    required this.text,
    required this.fill,
    required this.line,
    required this.textColor,
    this.size = 40,
    this.font,
    this.c,
  });
  final String text;
  final Color fill, line, textColor;
  final double size;
  final String? font;
  final Ctx? c;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _StarPainter(fill, line),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: font ?? 'IBMPlexSansArabic',
            fontSize: size * 0.32,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    ),
  );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.fill, this.line);
  final Color fill, line;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    final outer = starPath(c, r);
    canvas.drawPath(outer, Paint()..color = fill);
    canvas.drawPath(
      outer,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      c,
      r * 0.58,
      Paint()
        ..color = line.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_StarPainter o) => false;
}

/// Kaaba: a cube draped in black with the gold band (hizam) and door.
class KaabaPainter extends CustomPainter {
  KaabaPainter({this.outline});
  final Color? outline;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final front = Path()
      ..moveTo(w * .10, h * .30)
      ..lineTo(w * .62, h * .38)
      ..lineTo(w * .62, h * .94)
      ..lineTo(w * .10, h * .84)
      ..close();
    final side = Path()
      ..moveTo(w * .62, h * .38)
      ..lineTo(w * .92, h * .26)
      ..lineTo(w * .92, h * .80)
      ..lineTo(w * .62, h * .94)
      ..close();
    final top = Path()
      ..moveTo(w * .10, h * .30)
      ..lineTo(w * .42, h * .18)
      ..lineTo(w * .92, h * .26)
      ..lineTo(w * .62, h * .38)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF1A1714));
    canvas.drawPath(side, Paint()..color = const Color(0xFF2E2924));
    canvas.drawPath(top, Paint()..color = const Color(0xFF45403A));
    const gold = Color(0xFFD9AE4E);
    final band = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * .055;
    canvas.drawLine(Offset(w * .10, h * .42), Offset(w * .62, h * .50), band);
    canvas.drawLine(Offset(w * .62, h * .50), Offset(w * .92, h * .385), band);
    // Door, raised on the front face.
    canvas.drawPath(
      Path()
        ..moveTo(w * .40, h * .60)
        ..lineTo(w * .52, h * .62)
        ..lineTo(w * .52, h * .82)
        ..lineTo(w * .40, h * .80)
        ..close(),
      Paint()..color = gold,
    );
    if (outline != null) {
      final o = Paint()
        ..color = outline!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas
        ..drawPath(front, o)
        ..drawPath(side, o)
        ..drawPath(top, o);
    }
  }

  @override
  bool shouldRepaint(KaabaPainter o) => false;
}

/// The green dome on its drum with a crescent finial.
class DomePainter extends CustomPainter {
  DomePainter({this.outline});
  final Color? outline;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    const green = Color(0xFF2E8B5A);
    const dark = Color(0xFF1E6A43);
    final drum = Rect.fromLTWH(w * .18, h * .66, w * .64, h * .26);
    canvas.drawRect(drum, Paint()..color = dark);
    // Drum windows.
    final win = Paint()..color = const Color(0xFFBFE3CD);
    for (var i = 0; i < 4; i++) {
      final x = w * (.26 + i * .14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * .72, w * .06, h * .14),
          Radius.circular(w * .03),
        ),
        win,
      );
    }
    final dome = Path()
      ..moveTo(w * .14, h * .67)
      ..cubicTo(w * .10, h * .40, w * .34, h * .28, w * .50, h * .16)
      ..cubicTo(w * .66, h * .28, w * .90, h * .40, w * .86, h * .67)
      ..close();
    canvas.drawPath(
      dome,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF4FB27C), green, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    const gold = Color(0xFFD9AE4E);
    canvas.drawLine(
      Offset(w * .5, h * .17),
      Offset(w * .5, h * .06),
      Paint()
        ..color = gold
        ..strokeWidth = w * .04,
    );
    final moon = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * .5, h * .05), radius: w * .07),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        moon,
        Path()..addOval(
          Rect.fromCircle(center: Offset(w * .535, h * .035), radius: w * .06),
        ),
      ),
      Paint()..color = gold,
    );
    if (outline != null) {
      canvas.drawPath(
        dome,
        Paint()
          ..color = outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(DomePainter o) => false;
}

class RevelationMark extends StatelessWidget {
  const RevelationMark({
    super.key,
    required this.meccan,
    required this.c,
    this.size = 30,
  });
  final bool meccan;
  final Ctx c;
  final double size;
  @override
  Widget build(BuildContext context) {
    final outline = c.look.night ? c.look.gold.withValues(alpha: .6) : null;
    return Semantics(
      label: meccan ? c.s('مكية', 'Meccan') : c.s('مدنية', 'Medinan'),
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: meccan
                ? KaabaPainter(outline: outline)
                : DomePainter(outline: outline),
          ),
        ),
      ),
    );
  }
}

/// Repeating star-and-cross lattice.
class GirihPainter extends CustomPainter {
  GirihPainter(this.color, {this.cell = 56, this.stroke = 1});
  final Color color;
  final double cell, stroke;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (var y = 0.0; y < s.height + cell; y += cell) {
      for (var x = 0.0; x < s.width + cell; x += cell) {
        canvas.drawPath(starPath(Offset(x, y), cell * .5, inner: .72), p);
        canvas.drawPath(
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
  }

  @override
  bool shouldRepaint(GirihPainter o) => false;
}

/// A tazhib band: chained lozenges with lapis dots between gold rules.
class TazhibBand extends StatelessWidget {
  const TazhibBand({super.key, required this.look, this.height = 14});
  final Look look;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _BandPainter(look)),
  );
}

class _BandPainter extends CustomPainter {
  _BandPainter(this.l);
  final Look l;
  @override
  void paint(Canvas canvas, Size s) {
    final g = Paint()
      ..color = l.gold
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset.zero, Offset(s.width, 0), g)
      ..drawLine(Offset(0, s.height), Offset(s.width, s.height), g);
    final step = s.height * 1.4;
    final fill = Paint()..color = l.gold;
    final dot = Paint()..color = l.accent2;
    final cy = s.height / 2;
    for (var x = step / 2; x < s.width; x += step) {
      final r = s.height * .36;
      canvas.drawPath(
        Path()
          ..moveTo(x - r, cy)
          ..quadraticBezierTo(x, cy - r * 1.3, x + r, cy)
          ..quadraticBezierTo(x, cy + r * 1.3, x - r, cy),
        fill,
      );
      canvas.drawCircle(Offset(x + step / 2, cy), s.height * .12, dot);
    }
  }

  @override
  bool shouldRepaint(_BandPainter o) => false;
}

/// Pointed (mihrab) arch outline.
Path archPath(Size s, {double spring = .42}) {
  final w = s.width, h = s.height;
  final sy = math.min(w * spring, h * .6);
  return Path()
    ..moveTo(0, h)
    ..lineTo(0, sy)
    ..cubicTo(0, sy * .45, w * .32, sy * .18, w / 2, 0)
    ..cubicTo(w * .68, sy * .18, w, sy * .45, w, sy)
    ..lineTo(w, h)
    ..close();
}

class ArchClipper extends CustomClipper<Path> {
  const ArchClipper({this.spring = .42});
  final double spring;
  @override
  Path getClip(Size size) => archPath(size, spring: spring);
  @override
  bool shouldReclip(ArchClipper o) => false;
}

class _ArchBorder extends CustomPainter {
  _ArchBorder(this.color, {this.spring = .42, this.inset = 6});
  final Color color;
  final double spring, inset;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(archPath(s, spring: spring), p);
    canvas.save();
    canvas.translate(inset, inset);
    canvas.drawPath(
      archPath(Size(s.width - inset * 2, s.height - inset * 2), spring: spring),
      p..strokeWidth = .7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArchBorder o) => false;
}

/// Scattered small stars for the night sky.
class SkyPainter extends CustomPainter {
  SkyPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final r = math.Random(7);
    for (var i = 0; i < 70; i++) {
      final o = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      final big = r.nextDouble() > .9;
      canvas.drawPath(
        starPath(o, big ? 3.2 : 1.4, points: 4, inner: .35),
        Paint()..color = color.withValues(alpha: big ? .55 : .25),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter o) => false;
}

class Ring extends CustomPainter {
  Ring(this.value, this.color, this.track, {this.width = 4});
  final double value, width;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(width / 2),
      0,
      math.pi * 2,
      false,
      p..color = track,
    );
    canvas.drawArc(
      rect.deflate(width / 2),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(Ring o) => false;
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _Sec {
  const _Sec(this.ar, this.en, this.icon);
  final String ar, en;
  final IconData icon;
}

const _sections = [
  _Sec('المصحف', 'Mushaf', Icons.menu_book_outlined),
  _Sec('الاستماع', 'Listen', Icons.headphones_outlined),
  _Sec('التفسير', 'Tafsir', Icons.auto_stories_outlined),
  _Sec('البحث', 'Search', Icons.search),
  _Sec('الختمة', 'Khatma', Icons.flag_outlined),
  _Sec('الحفظ', 'Memorise', Icons.psychology_outlined),
  _Sec('التسميع', 'Recite', Icons.mic_none_outlined),
  _Sec('المساعد', 'Assistant', Icons.forum_outlined),
];

/// The app's logo calligraphy (assets/ornaments/share_logo.png), set by the
/// render tool. Tinted per look; never re-typeset in a font.
ui.Image? logoImage;

Widget logo(Ctx c, Color color, {double size = 34}) => Semantics(
  header: true,
  label: c.s('تبيان', 'Tibyan'),
  child: ExcludeSemantics(
    child: RawImage(
      image: logoImage,
      height: size * 1.25,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    ),
  ),
);

Widget iconBtn(IconData i, Color color, String label) => Semantics(
  button: true,
  label: label,
  child: SizedBox.square(dimension: 48, child: Icon(i, color: color, size: 24)),
);

/// The screen root. Wide layouts get a side rail and a centred column.
class Shell extends StatelessWidget {
  const Shell({
    super.key,
    required this.c,
    required this.child,
    this.background,
    this.selected = 0,
  });
  final Ctx c;
  final Widget child;
  final Widget? background;
  final int selected;
  @override
  Widget build(BuildContext context) {
    final l = c.look;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final body = Stack(
      children: [
        if (background != null) Positioned.fill(child: background!),
        child,
      ],
    );
    return Directionality(
      textDirection: c.english ? TextDirection.ltr : TextDirection.rtl,
      child: Material(
        color: l.bg,
        child: wide
            ? Row(
                children: [
                  _rail(c),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    );
  }

  Widget _rail(Ctx c) {
    final l = c.look;
    final items = [
      (c.s('الرئيسية', 'Home'), Icons.home_outlined),
      (c.s('الفهرس', 'Index'), Icons.list_alt),
      (c.s('الاستماع', 'Listen'), Icons.headphones_outlined),
      (c.s('الإعدادات', 'Settings'), Icons.tune),
    ];
    return Container(
      width: 248,
      color: l.frame,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GirihPainter(l.onFrame.withValues(alpha: .07), cell: 64),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: logo(c, l.onFrame, size: 52)),
                const SizedBox(height: 28),
                for (var i = 0; i < items.length; i++)
                  Container(
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? l.onFrame.withValues(alpha: .14)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(items[i].$2, color: l.onFrame, size: 22),
                        const SizedBox(width: 14),
                        Text(
                          items[i].$1,
                          style: ts(
                            c,
                            16,
                            l.onFrame,
                            w: i == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget centred(BuildContext context, Widget child, {double max = 720}) =>
    Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );

// ---------------------------------------------------------------------------
// HOME
// ---------------------------------------------------------------------------

class HomeProto extends StatelessWidget {
  const HomeProto(this.c, {super.key});
  final Ctx c;

  @override
  Widget build(BuildContext context) {
    final l = c.look;
    final bg = switch (l.dir) {
      Dir.makhtuta => CustomPaint(
        painter: GirihPainter(
          l.gold.withValues(alpha: l.night ? .06 : .09),
          cell: 72,
        ),
      ),
      Dir.handasi => Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          height: 260,
          child: CustomPaint(
            size: const Size(double.infinity, 260),
            painter: GirihPainter(
              l.accent.withValues(alpha: l.night ? .16 : .10),
              cell: 44,
            ),
          ),
        ),
      ),
      Dir.layli =>
        l.night
            ? CustomPaint(painter: SkyPainter(l.gold))
            : CustomPaint(
                painter: GirihPainter(l.gold.withValues(alpha: .07), cell: 80),
              ),
    };
    return Shell(
      c: c,
      background: bg,
      child: SafeArea(
        child: centred(
          context,
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _topBar(context),
              const SizedBox(height: 12),
              _hero(),
              const SizedBox(height: 16),
              _today(),
              const SizedBox(height: 24),
              if (c.elderly) ..._elderlyTiles() else _grid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final l = c.look;
    final wide = MediaQuery.sizeOf(context).width > 900;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (!wide)
            switch (l.dir) {
              Dir.makhtuta => Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: l.frame,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: l.gold, width: 1.2),
                ),
                child: logo(c, l.onFrame, size: 30),
              ),
              Dir.handasi => Row(
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: CustomPaint(
                      painter: _StarPainter(l.accent, l.accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  logo(c, l.ink, size: 32),
                ],
              ),
              Dir.layli => logo(c, l.gold, size: 36),
            }
          else
            Text(
              c.s('السلام عليكم', 'Peace be upon you'),
              style: ts(c, 22, l.ink, font: c.english ? null : l.headFont),
            ),
          const Spacer(),
          iconBtn(Icons.search, l.ink, c.s('بحث', 'Search')),
          iconBtn(Icons.tune, l.ink, c.s('الإعدادات', 'Settings')),
        ],
      ),
    );
  }

  // --- continue-reading hero, one per direction -----------------------------

  Widget _hero() => switch (c.look.dir) {
    Dir.makhtuta => _heroMakhtuta(),
    Dir.handasi => _heroHandasi(),
    Dir.layli => _heroLayli(),
  };

  Widget _heroText(Color ink, Color sub, {bool center = false}) => Column(
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        c.s('تابع من حيث توقفت', 'Continue where you stopped'),
        style: ts(c, 13, sub),
      ),
      Text(
        'البقرة',
        style: TextStyle(
          fontFamily: c.look.nameFont,
          fontSize: c.look.dir == Dir.handasi ? 40 : 46,
          color: ink,
          height: 1.35,
        ),
      ),
      Text(
        c.s('الآية ${ar(255)} · صفحة ${ar(42)}', 'Al-Baqara 2:255 · page 42'),
        style: ts(c, 14, sub, w: FontWeight.w500),
      ),
    ],
  );

  Widget _primary(String label, Color bg, Color fg, {double radius = 24}) =>
      Semantics(
        button: true,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Text(label, style: ts(c, 15, fg, w: FontWeight.w600)),
        ),
      );

  Widget _heroMakhtuta() {
    final l = c.look;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: l.frame,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: l.surface,
          border: Border.all(color: l.gold, width: 1.4),
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            TazhibBand(look: l),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _heroText(l.ink, l.sub)),
                SizedBox.square(
                  dimension: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(96),
                        painter: _StarPainter(
                          l.gold.withValues(alpha: .14),
                          l.gold,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.s('سورة', 'Surah'),
                            style: ts(c, 11, l.sub, h: 1),
                          ),
                          Text(
                            c.n(2),
                            style: ts(
                              c,
                              26,
                              l.accent,
                              w: FontWeight.w600,
                              h: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _primary(
                    c.s('تابع القراءة', 'Continue reading'),
                    l.accent,
                    l.night ? l.frame : l.surface,
                    radius: 6,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: l.accent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: l.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroHandasi() {
    final l = c.look;
    final fg = l.night ? l.bg : l.surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: l.night ? l.accent : l.accent,
        child: Stack(
          children: [
            Positioned(
              left: c.english ? null : -40,
              right: c.english ? -40 : null,
              top: -30,
              child: SizedBox.square(
                dimension: 200,
                child: CustomPaint(
                  painter: GirihPainter(fg.withValues(alpha: .22), cell: 50),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroText(fg, fg.withValues(alpha: .82)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _primary(
                        c.s('تابع القراءة', 'Continue reading'),
                        fg,
                        l.accent,
                        radius: 12,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        c.s('آخر قراءة: أمس ٩:٤٠ م', 'Last read: yesterday'),
                        style: ts(c, 12, fg.withValues(alpha: .8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroLayli() {
    final l = c.look;
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: const ArchClipper(spring: .34),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: l.night
                        ? [const Color(0xFF1B2D50), l.surface]
                        : [const Color(0xFF14203A), const Color(0xFF223459)],
                  ),
                ),
                child: CustomPaint(
                  painter: SkyPainter(const Color(0xFFE6C47A)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ArchBorder(
                l.night ? l.gold : const Color(0xFFE6C47A),
                spring: .34,
                inset: 7,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
              child: Column(
                children: [
                  _heroText(
                    const Color(0xFFF3E2B4),
                    const Color(0xFFC9CFDC),
                    center: true,
                  ),
                  const Spacer(),
                  _primary(
                    c.s('تابع القراءة', 'Continue reading'),
                    const Color(0xFFE6C47A),
                    const Color(0xFF14203A),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- today's khatma portion ----------------------------------------------

  Widget _today() {
    final l = c.look;
    const done = 7, total = 20;
    final radius = switch (l.dir) {
      Dir.makhtuta => 4.0,
      Dir.handasi => 16.0,
      Dir.layli => 14.0,
    };
    return Semantics(
      container: true,
      label: c.s('ورد اليوم: ٧ من ٢٠ صفحة', "Today's portion: 7 of 20 pages"),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: l.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: l.dir == Dir.handasi
                ? l.ink.withValues(alpha: .08)
                : l.gold.withValues(alpha: .55),
          ),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 60,
              child: CustomPaint(
                painter: Ring(
                  done / total,
                  l.dir == Dir.handasi ? l.accent2 : l.gold,
                  l.ink.withValues(alpha: .1),
                  width: 5,
                ),
                child: Center(
                  child: Text(
                    c.english ? '35%' : '٪٣٥',
                    style: ts(c, 14, l.ink, w: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.s('ورد اليوم · ${juzName(3)}', "Today's portion · Juz 3"),
                    style: ts(c, 16, l.ink, w: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.s(
                      'من صفحة ${ar(42)} إلى ${ar(61)} · بقي ${ar(13)} صفحة',
                      'Pages 42 to 61 · 13 left',
                    ),
                    style: ts(c, 13, l.sub),
                  ),
                ],
              ),
            ),
            Icon(
              c.english ? Icons.chevron_right : Icons.chevron_left,
              color: l.sub,
            ),
          ],
        ),
      ),
    );
  }

  // --- section tiles ---------------------------------------------------------

  Widget _grid(BuildContext context) {
    final l = c.look;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final cols = wide ? 8 : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, right: 4, left: 4),
          child: Text(
            c.s('الأقسام', 'Sections'),
            style: ts(c, 20, l.ink, font: c.english ? null : l.headFont),
          ),
        ),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: l.dir == Dir.layli ? .66 : .78,
          children: [for (final s in _sections) _tile(s)],
        ),
      ],
    );
  }

  Widget _tile(_Sec s) {
    final l = c.look;
    final label = c.s(s.ar, s.en);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: ts(c, 13, l.ink, w: FontWeight.w500),
    );
    final Widget icon;
    switch (l.dir) {
      case Dir.makhtuta:
        icon = SizedBox.square(
          dimension: 62,
          child: CustomPaint(
            painter: _StarPainter(l.surface, l.gold),
            child: Icon(s.icon, color: l.accent, size: 24),
          ),
        );
      case Dir.handasi:
        icon = Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: l.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: l.ink.withValues(alpha: .08)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(44),
                painter: _StarPainter(
                  l.accent.withValues(alpha: .10),
                  l.accent.withValues(alpha: .0),
                ),
              ),
              Icon(s.icon, color: l.accent, size: 24),
            ],
          ),
        );
      case Dir.layli:
        icon = SizedBox(
          width: 64,
          height: 78,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipPath(
                  clipper: const ArchClipper(spring: .5),
                  child: ColoredBox(color: l.surface),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArchBorder(
                    l.gold.withValues(alpha: .8),
                    spring: .5,
                    inset: 4,
                  ),
                ),
              ),
              Positioned.fill(
                top: 20,
                child: Icon(s.icon, color: l.gold, size: 24),
              ),
            ],
          ),
        );
    }
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(children: [icon, const SizedBox(height: 8), text]),
      ),
    );
  }

  List<Widget> _elderlyTiles() {
    final l = c.look;
    Widget big(_Sec s, String detail) => Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: l.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: l.gold, width: 1.4),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 56,
            child: CustomPaint(
              painter: _StarPainter(l.accent, l.gold),
              child: Icon(s.icon, color: l.surface, size: 26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.s(s.ar, s.en),
                  style: ts(c, 22, l.ink, w: FontWeight.w600),
                ),
                Text(detail, style: ts(c, 15, l.sub)),
              ],
            ),
          ),
        ],
      ),
    );
    return [
      big(_sections[0], c.s('افتح المصحف', 'Open the mushaf')),
      big(_sections[1], c.s('استمع للتلاوة', 'Listen to a recitation')),
      big(_sections[3], c.s('ابحث عن آية', 'Find a verse')),
    ];
  }
}

// ---------------------------------------------------------------------------
// INDEX
// ---------------------------------------------------------------------------

class IndexProto extends StatelessWidget {
  const IndexProto(this.c, {super.key, this.tab = 0});
  final Ctx c;
  final int tab;

  @override
  Widget build(BuildContext context) {
    final l = c.look;
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Shell(
      c: c,
      selected: 1,
      background: l.dir == Dir.layli && l.night
          ? CustomPaint(painter: SkyPainter(l.gold))
          : null,
      child: SafeArea(
        child: Column(
          children: [
            _header(context),
            _tabs(),
            Expanded(
              child: tab == 0
                  ? _surahList(context, wide)
                  : _juzGrid(context, wide),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l = c.look;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            iconBtn(
              c.english ? Icons.arrow_back : Icons.arrow_forward,
              l.ink,
              c.s('رجوع', 'Back'),
            ),
            Expanded(
              child: Center(
                child: Text(
                  c.s('الفهرس', 'Index'),
                  style: ts(
                    c,
                    l.dir == Dir.handasi ? 20 : 26,
                    l.dir == Dir.layli ? l.gold : l.ink,
                    font: c.english ? null : l.headFont,
                  ),
                ),
              ),
            ),
            iconBtn(Icons.search, l.ink, c.s('بحث', 'Search')),
          ],
        ),
      ),
    );
  }

  Widget _tabs() {
    final l = c.look;
    final names = [
      c.s('السور', 'Surahs'),
      c.s('الأجزاء', 'Juz'),
      c.s('الأحزاب', 'Hizb'),
      c.s('الصفحات', 'Pages'),
    ];
    Widget item(int i) {
      final on = i == tab;
      final Color fg;
      final BoxDecoration? deco;
      switch (l.dir) {
        case Dir.makhtuta:
          fg = on ? l.onFrame : l.sub;
          deco = on
              ? BoxDecoration(
                  color: l.frame,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: l.gold),
                )
              : null;
        case Dir.handasi:
          fg = on ? l.accent : l.sub;
          deco = on
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: l.accent, width: 3)),
                )
              : null;
        case Dir.layli:
          fg = on ? (l.night ? l.bg : l.onFrame) : l.sub;
          deco = on
              ? BoxDecoration(
                  color: l.night ? l.gold : l.frame,
                  borderRadius: BorderRadius.circular(24),
                )
              : null;
      }
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.center,
            decoration: deco,
            child: Text(
              names[i],
              style: ts(c, 15, fg, w: on ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: l.dir == Dir.handasi ? null : const EdgeInsets.all(4),
        decoration: switch (l.dir) {
          Dir.makhtuta => BoxDecoration(
            color: l.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: l.gold.withValues(alpha: .5)),
          ),
          Dir.handasi => BoxDecoration(
            border: Border(
              bottom: BorderSide(color: l.ink.withValues(alpha: .1)),
            ),
          ),
          Dir.layli => BoxDecoration(
            color: l.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: l.gold.withValues(alpha: .35)),
          ),
        },
        child: Row(children: [for (var i = 0; i < 4; i++) item(i)]),
      ),
    );
  }

  // --- surahs ----------------------------------------------------------------

  Widget _surahList(BuildContext context, bool wide) {
    final l = c.look;
    final entries = <Widget>[];
    var lastJuz = 0;
    for (final s in c.data.surahs) {
      if (s.juz != lastJuz && !wide) {
        entries.add(_juzDivider(s.juz));
        lastJuz = s.juz;
      }
      entries.add(_row(s));
    }
    final Widget list = wide
        ? GridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 12,
            childAspectRatio: 6.2,
            children: [for (final s in c.data.surahs) _row(s)],
          )
        : ListView(padding: EdgeInsets.zero, children: entries);
    final content = centred(context, list, max: wide ? 1100 : 720);
    if (l.dir == Dir.makhtuta) {
      // Paper rows inside a dark illuminated frame.
      return Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: l.frame,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: l.gold, width: 1.2),
          ),
          child: ClipRect(child: content),
        ),
      );
    }
    return content;
  }

  Widget _juzDivider(int j) {
    final l = c.look;
    final label = c.english ? 'Juz $j' : juzName(j);
    switch (l.dir) {
      case Dir.makhtuta:
        return Container(
          height: 40,
          color: l.frame,
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(child: TazhibBand(look: l, height: 10)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: l.gold),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: c.english ? c.ui : 'ArefRuqaa',
                    fontSize: 16,
                    color: l.onFrame,
                  ),
                ),
              ),
              Expanded(child: TazhibBand(look: l, height: 10)),
            ],
          ),
        );
      case Dir.handasi:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 14,
                child: CustomPaint(painter: _StarPainter(l.accent2, l.accent2)),
              ),
              const SizedBox(width: 8),
              Text(label, style: ts(c, 13, l.accent2, w: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(height: 1, color: l.ink.withValues(alpha: .1)),
              ),
            ],
          ),
        );
      case Dir.layli:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [l.gold.withValues(alpha: 0), l.gold],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: c.english ? c.ui : 'ArefRuqaa',
                    fontSize: 17,
                    color: l.gold,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [l.gold, l.gold.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _name(SurahRow s, double size, Color color) {
    final name = Text(
      s.nameAr,
      maxLines: 1,
      style: TextStyle(
        fontFamily: c.look.nameFont,
        fontSize: size,
        color: color,
        height: 1.45,
      ),
    );
    if (!c.english) return name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.nameEn, style: ts(c, 16, color, w: FontWeight.w600)),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            s.nameAr,
            style: TextStyle(
              fontFamily: c.look.nameFont,
              fontSize: size * .6,
              color: c.look.sub,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  String _ayahs(SurahRow s) =>
      c.s('آياتها ${ar(s.ayahs)}', '${s.ayahs} verses');

  Widget _row(SurahRow s) {
    final l = c.look;
    final h = c.elderly ? 96.0 : 76.0;
    final semantics = c.s(
      'سورة ${s.nameAr}، رقم ${s.id}، آياتها ${s.ayahs}، '
          '${s.meccan ? 'مكية' : 'مدنية'}، تبدأ في صفحة ${s.page}',
      'Surah ${s.nameEn}, number ${s.id}, ${s.ayahs} verses, '
          '${s.meccan ? 'Meccan' : 'Medinan'}, starts on page ${s.page}',
    );
    final Widget row;
    switch (l.dir) {
      case Dir.makhtuta:
        row = Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 2),
          color: l.row,
          child: Row(
            children: [
              const SizedBox(width: 10),
              StarBadge(
                text: c.n(s.id),
                fill: l.night ? l.surface : const Color(0xFFF1E1C2),
                line: l.gold,
                textColor: l.accent,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(child: _name(s, c.elderly ? 34 : 28, l.ink)),
              Text(_ayahs(s), style: ts(c, c.elderly ? 16 : 13, l.sub)),
              const SizedBox(width: 10),
              RevelationMark(meccan: s.meccan, c: c, size: 30),
              const SizedBox(width: 10),
              Container(
                width: 54,
                height: h,
                color: l.frame,
                alignment: Alignment.center,
                child: Text(
                  c.n(s.page),
                  style: ts(
                    c,
                    c.elderly ? 20 : 17,
                    l.onFrame,
                    w: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      case Dir.handasi:
        row = Container(
          height: h,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: l.row,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: l.ink.withValues(alpha: .07)),
          ),
          child: Row(
            children: [
              StarBadge(
                text: c.n(s.id),
                fill: l.accent.withValues(alpha: .10),
                line: l.accent.withValues(alpha: .5),
                textColor: l.accent,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _name(s, c.elderly ? 30 : 24, l.ink),
                    if (!c.english)
                      Text(
                        '${_ayahs(s)} · ${s.meccan ? 'مكية' : 'مدنية'}',
                        style: ts(c, c.elderly ? 15 : 12, l.sub, h: 1.1),
                      ),
                  ],
                ),
              ),
              RevelationMark(meccan: s.meccan, c: c, size: 28),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: l.accent2.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  c.n(s.page),
                  style: ts(
                    c,
                    15,
                    l.night ? l.accent2 : l.accent2,
                    w: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      case Dir.layli:
        row = Container(
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: l.gold.withValues(alpha: .18)),
            ),
          ),
          child: Row(
            children: [
              StarBadge(
                text: c.n(s.id),
                fill: Colors.transparent,
                line: l.gold,
                textColor: l.gold,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _name(s, c.elderly ? 34 : 30, l.night ? l.ink : l.ink),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RevelationMark(meccan: s.meccan, c: c, size: 28),
                  const SizedBox(height: 2),
                  Text(_ayahs(s), style: ts(c, 11, l.sub)),
                ],
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 44,
                height: 56,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: const ArchClipper(spring: .5),
                        child: ColoredBox(color: l.night ? l.surface : l.frame),
                      ),
                    ),
                    Positioned.fill(
                      top: 18,
                      child: Center(
                        child: Text(
                          c.n(s.page),
                          style: ts(
                            c,
                            14,
                            l.night ? l.gold : l.onFrame,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(child: row),
    );
  }

  // --- juz grid --------------------------------------------------------------

  Widget _juzGrid(BuildContext context, bool wide) {
    final l = c.look;
    return centred(
      context,
      GridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: wide ? 5 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          for (final j in c.data.juz)
            Semantics(
              button: true,
              label:
                  '${juzName(j.juz)}، يبدأ من ${j.surahAr} آية ${j.ayah}، '
                  'صفحة ${j.page}',
              child: ExcludeSemantics(
                child: Container(
                  decoration: BoxDecoration(
                    color: l.dir == Dir.makhtuta ? l.surface : l.row,
                    borderRadius: BorderRadius.circular(
                      l.dir == Dir.makhtuta ? 4 : 16,
                    ),
                    border: Border.all(
                      color: l.dir == Dir.handasi
                          ? l.ink.withValues(alpha: .08)
                          : l.gold.withValues(alpha: .6),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StarBadge(
                            text: c.n(j.juz),
                            fill: l.dir == Dir.handasi
                                ? l.accent
                                : l.gold.withValues(alpha: .15),
                            line: l.dir == Dir.handasi ? l.accent : l.gold,
                            textColor: l.dir == Dir.handasi
                                ? l.surface
                                : l.accent,
                            size: 40,
                          ),
                          const Spacer(),
                          Text(
                            c.s('ص ${ar(j.page)}', 'p. ${j.page}'),
                            style: ts(c, 13, l.sub),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        c.english ? 'Juz ${j.juz}' : juzName(j.juz),
                        style: ts(c, 15, l.ink, w: FontWeight.w600),
                      ),
                      Text(
                        c.s(
                          '${j.surahAr} · آية ${ar(j.ayah)}',
                          '${j.surahAr} ${j.ayah}',
                        ),
                        style: ts(c, 13, l.sub),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS
// ---------------------------------------------------------------------------

class SettingsProto extends StatelessWidget {
  const SettingsProto(this.c, {super.key});
  final Ctx c;

  @override
  Widget build(BuildContext context) {
    final l = c.look;
    return Shell(
      c: c,
      selected: 3,
      background: l.dir == Dir.layli && l.night
          ? CustomPaint(painter: SkyPainter(l.gold))
          : null,
      child: SafeArea(
        child: centred(
          context,
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    iconBtn(Icons.arrow_forward, l.ink, c.s('رجوع', 'Back')),
                    Expanded(
                      child: Center(
                        child: Text(
                          c.s('الإعدادات', 'Settings'),
                          style: ts(
                            c,
                            l.dir == Dir.handasi ? 20 : 26,
                            l.dir == Dir.layli ? l.gold : l.ink,
                            font: l.headFont,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _group(Icons.palette_outlined, 'المظهر', [
                _themePicker(),
                _modePicker(),
                _toggle('وضع كبار السن', 'خط أكبر وأزرار أوضح', false),
              ]),
              _group(Icons.menu_book_outlined, 'القراءة', [
                _segmented('الطبعة', ['١٤٤١ هـ', '١٤٠٥ هـ', 'الشمرلي'], 0),
                _nav('الرواية', 'حفص عن عاصم'),
                _toggle('إبقاء الشاشة مضاءة', null, true),
                _toggle('تمييز لفظ الجلالة', 'بلون مختلف في الصفحة', true),
                _toggle('صفحتان متقابلتان', 'في الشاشات العريضة', false),
              ]),
              _group(Icons.headphones_outlined, 'الاستماع', [
                _nav('شكل المشغل', 'شريط مدمج'),
                _nav('مؤقت سجود التلاوة', 'متوقف'),
              ]),
              _group(Icons.inventory_2_outlined, 'البيانات', [
                _nav('النسخ الاحتياطي', 'آخر نسخة: منذ ٣ أيام'),
                _nav('التخزين', '١٫٢ جيجابايت'),
              ]),
              _group(Icons.info_outline, 'عن تبيان', [
                _nav('ما الجديد', null),
                _nav('الإصدار', '٢٫٤٫٠'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(IconData icon, String title, List<Widget> rows) {
    final l = c.look;
    final divided = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        divided.add(
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: l.ink.withValues(alpha: .08),
          ),
        );
      }
      divided.add(rows[i]);
    }
    final Widget head;
    switch (l.dir) {
      case Dir.makhtuta:
        head = Container(
          height: 44,
          decoration: BoxDecoration(
            color: l.frame,
            border: Border(bottom: BorderSide(color: l.gold, width: 1.2)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              StarBadge(
                text: '',
                fill: l.frame,
                line: l.gold,
                textColor: l.gold,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ArefRuqaa',
                  fontSize: 19,
                  color: l.onFrame,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: TazhibBand(look: l, height: 8)),
              const SizedBox(width: 12),
            ],
          ),
        );
      case Dir.handasi:
        head = Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: l.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: l.surface),
              ),
              const SizedBox(width: 10),
              Text(title, style: ts(c, 16, l.ink, font: l.headFont)),
            ],
          ),
        );
      case Dir.layli:
        head = Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 32,
                child: CustomPaint(
                  painter: _ArchBorder(l.gold, spring: .5, inset: 3),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ArefRuqaa',
                  fontSize: 21,
                  color: l.gold,
                ),
              ),
            ],
          ),
        );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: l.surface,
        borderRadius: BorderRadius.circular(switch (l.dir) {
          Dir.makhtuta => 4,
          Dir.handasi => 18,
          Dir.layli => 16,
        }),
        border: Border.all(
          color: l.dir == Dir.handasi
              ? l.ink.withValues(alpha: .07)
              : l.gold.withValues(alpha: l.dir == Dir.makhtuta ? .9 : .35),
          width: l.dir == Dir.makhtuta ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [head, ...divided, const SizedBox(height: 4)],
      ),
    );
  }

  Widget _tile(String title, String? sub, Widget trailing) {
    final l = c.look;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: ts(c, 16, l.ink, w: FontWeight.w500)),
                  if (sub != null) Text(sub, style: ts(c, 13, l.sub)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Color get _on => switch (c.look.dir) {
    Dir.makhtuta => c.look.accent,
    Dir.handasi => c.look.accent,
    Dir.layli => c.look.night ? c.look.gold : c.look.frame,
  };

  Widget _toggle(String title, String? sub, bool on) {
    final l = c.look;
    return Semantics(
      toggled: on,
      label: title,
      child: _tile(
        title,
        sub,
        Container(
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          alignment: on
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: on ? _on : l.ink.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: on ? (l.night ? l.bg : l.surface) : l.surface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _nav(String title, String? value) {
    final l = c.look;
    return Semantics(
      button: true,
      child: _tile(
        title,
        null,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) Text(value, style: ts(c, 14, l.sub)),
            Icon(Icons.chevron_left, color: l.sub),
          ],
        ),
      ),
    );
  }

  Widget _segmented(String title, List<String> opts, int sel) {
    final l = c.look;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ts(c, 16, l.ink, w: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: l.ink.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (var i = 0; i < opts.length; i++)
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: i == sel
                          ? BoxDecoration(
                              color: _on,
                              borderRadius: BorderRadius.circular(9),
                            )
                          : null,
                      child: Text(
                        opts[i],
                        style: ts(
                          c,
                          14,
                          i == sel ? (l.night ? l.bg : l.surface) : l.ink,
                          w: i == sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themePicker() {
    final l = c.look;
    const styles = [
      ('زخرفة', Color(0xFF1F7A78), Color(0xFFD9822B)),
      ('السلجوقي', Color(0xFF23466E), Color(0xFFB8892E)),
      ('المملوكي', Color(0xFF7A2E1E), Color(0xFFC9A04A)),
      ('الأندلسي', Color(0xFF2E6B4A), Color(0xFFC07A3A)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نمط المصحف', style: ts(c, 16, l.ink, w: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < styles.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7EDDE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: i == 0 ? _on : styles[i].$2,
                            width: i == 0 ? 3 : 4,
                          ),
                        ),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 26,
                            child: CustomPaint(
                              painter: _StarPainter(styles[i].$3, styles[i].$2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        styles[i].$1,
                        style: ts(
                          c,
                          12,
                          i == 0 ? l.ink : l.sub,
                          w: i == 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modePicker() {
    final l = c.look;
    const modes = [
      ('فاتح', Color(0xFFF7EDDE), Color(0xFF1E1915)),
      ('أبيض', Color(0xFFFFFFFF), Color(0xFF1E1915)),
      ('ليلي', Color(0xFF221A13), Color(0xFFEBDDC4)),
      ('أسود', Color(0xFF000000), Color(0xFFD8D0C2)),
    ];
    final sel = l.night ? 2 : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < modes.length; i++)
            Expanded(
              child: Semantics(
                selected: i == sel,
                button: true,
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: modes[i].$2,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: i == sel ? _on : l.ink.withValues(alpha: .15),
                      width: i == sel ? 2.5 : 1,
                    ),
                  ),
                  child: Text(
                    modes[i].$1,
                    style: ts(c, 14, modes[i].$3, w: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
