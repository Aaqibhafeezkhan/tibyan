import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/reveal.dart';

/// Card colours offered for tabs (and to any fasil): navy, mustard, cream,
/// then deeper tones.
const fasilCardColors = <int>[
  0xFF1D2F55,
  0xFFC69A3A,
  0xFFEFE3C6,
  0xFF8C2F2F,
  0xFF2E5E4A,
  0xFF5B1F3A,
];

/// The grey ornament drawn on a tab's dome, tinted to each card.
const fasilOrnamentAsset = 'assets/ornaments/fasil_arabesque.svg';

/// One named fasil as a page shows it.
@immutable
class FasilMark {
  const FasilMark({
    required this.id,
    required this.name,
    required this.color,
    required this.page,
    this.placedAt,
  });

  final int id;
  final String name;
  final Color color;

  /// Its page in the edition being read.
  final int page;

  /// When it was last placed (made or moved).
  final DateTime? placedAt;

  @override
  bool operator ==(Object other) =>
      other is FasilMark &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.page == page;

  @override
  int get hashCode => Object.hash(id, name, color, page);
}

/// What every bookmark on screen shares.
@immutable
class FasilLook {
  const FasilLook({
    required this.style,
    this.place = FasilPlace.top,
    this.material = FasilMaterial.silk,
    this.tassel = true,
    this.night = false,
    this.elderly = false,
    this.motion = true,
  });

  /// From the settings and the theme around [context].
  factory FasilLook.of(BuildContext context, AppSettings s) {
    final tokens = context.tokens;
    return FasilLook(
      style: s.effectiveFasilStyle,
      place: s.fasilPlace,
      material: s.fasilMaterial,
      tassel: s.fasilTassel,
      night: !tokens.mode.isLight,
      elderly: tokens.elderly,
      motion: !reduceMotion(context) && !tokens.elderly,
    );
  }

  /// [FasilStyle.ribbon] or [FasilStyle.tab]; [FasilStyle.tint] draws
  /// nothing here.
  final FasilStyle style;
  final FasilPlace place;
  final FasilMaterial material;
  final bool tassel;

  /// A dark paper: less sheen, a soft glow instead of a shadow.
  final bool night;

  /// Elderly mode: wider ribbons, bigger labels and targets, no motion.
  final bool elderly;

  /// Whether bookmarks animate as they are placed.
  final bool motion;

  bool get drawn => style != FasilStyle.tint;

  double get ribbonWidth => elderly ? 34 : 24;
  double get labelSize => elderly ? 15 : 11;
  double get tabWidth => elderly ? 80 : 62;
  double get target => elderly ? elderlyTarget : 48;

  @override
  bool operator ==(Object other) =>
      other is FasilLook &&
      other.style == style &&
      other.place == place &&
      other.material == material &&
      other.tassel == tassel &&
      other.night == night &&
      other.elderly == elderly &&
      other.motion == motion;

  @override
  int get hashCode =>
      Object.hash(style, place, material, tassel, night, elderly, motion);
}

/// Set just before a fasil is made or moved: the bookmark that then
/// appears drops (or rises) into place once.
final fasilJustPlaced = ValueNotifier<DateTime?>(null);

/// Arms the entrance of the next bookmark placed.
void armFasilEntrance() => fasilJustPlaced.value = DateTime.now();

bool _takeEntrance(FasilMark mark) {
  final armed = fasilJustPlaced.value;
  final placed = mark.placedAt;
  if (armed == null || placed == null) return false;
  final now = DateTime.now();
  if (now.difference(armed) > const Duration(seconds: 3)) return false;
  if (now.difference(placed).abs() > const Duration(seconds: 3)) return false;
  fasilJustPlaced.value = null;
  return true;
}

/// Dark text on a light card, light on a dark one.
Color fasilLabelColor(Color c) =>
    c.computeLuminance() > 0.55 ? const Color(0xFF4A3418) : Colors.white;

// ---------------------------------------------------------------------------
// The ribbon
// ---------------------------------------------------------------------------

/// The cloth's weave, drawn once per material into a small tile.
final _weaves = <FasilMaterial, ui.Image>{};

ui.Image _weave(FasilMaterial m) => _weaves.putIfAbsent(m, () {
  final size = switch (m) {
    FasilMaterial.silk => 2,
    FasilMaterial.linen => 3,
    FasilMaterial.velvet => 4,
  };
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final light = Paint()
    ..color = Color.fromARGB(
      switch (m) {
        FasilMaterial.silk => 18,
        FasilMaterial.linen => 36,
        FasilMaterial.velvet => 6,
      },
      255,
      255,
      255,
    );
  final dark = Paint()
    ..color = Color.fromARGB(
      switch (m) {
        FasilMaterial.silk => 26,
        FasilMaterial.linen => 46,
        FasilMaterial.velvet => 14,
      },
      0,
      0,
      0,
    );
  // Warp threads down, weft across; linen gets a slub every few rows.
  c.drawRect(Rect.fromLTWH(0, 0, 1, size.toDouble()), dark);
  c.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), 1), light);
  if (m == FasilMaterial.linen) {
    c.drawRect(const Rect.fromLTWH(1, 2, 2, 1), dark);
  }
  return rec.endRecording().toImageSync(size, size);
});

/// Pictures of ribbons already drawn, by everything that shapes them.
final _ribbonPictures = <Object, ui.Picture>{};

ui.Picture _ribbonPicture({
  required Size size,
  required Color color,
  required FasilMaterial material,
  required bool night,
  required bool folded,
}) {
  final key = (size, color, material, night, folded);
  final hit = _ribbonPictures.remove(key);
  if (hit != null) return _ribbonPictures[key] = hit;
  final rec = ui.PictureRecorder();
  _paintRibbon(
    Canvas(rec),
    size,
    color: color,
    material: material,
    night: night,
    folded: folded,
  );
  final picture = rec.endRecording();
  if (_ribbonPictures.length >= 48) {
    _ribbonPictures.remove(_ribbonPictures.keys.first)?.dispose();
  }
  return _ribbonPictures[key] = picture;
}

/// The ribbon's outline: straight sides and a forked tail.
Path ribbonPath(Size s) {
  final notch = math.min(s.width * 0.7, s.height * 0.3);
  return Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width / 2, s.height - notch)
    ..lineTo(0, s.height)
    ..close();
}

void _paintRibbon(
  Canvas canvas,
  Size s, {
  required Color color,
  required FasilMaterial material,
  required bool night,
  required bool folded,
}) {
  final path = ribbonPath(s);
  if (night) {
    // On dark paper a shadow is lost: a soft glow of the ribbon's colour.
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  } else {
    canvas.drawShadow(path.shift(const Offset(1.5, 1)), Colors.black, 3, false);
  }
  canvas.save();
  canvas.clipPath(path);
  final rect = Offset.zero & s;
  canvas.drawRect(rect, Paint()..color = color);
  // The weave, a tiled image.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ImageShader(
        _weave(material),
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      ),
  );
  // Light across the cloth: silk a broad sheen, linen hardly any, velvet
  // a soft glow in the middle and deep edges. Less at night.
  final sheen =
      (switch (material) {
        FasilMaterial.silk => .45,
        FasilMaterial.linen => .12,
        FasilMaterial.velvet => .16,
      }) *
      (night ? .5 : 1);
  final edge = material == FasilMaterial.velvet ? .55 : .35;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(s.width, 0),
        [
          Colors.black.withValues(alpha: edge),
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: sheen),
          Colors.white.withValues(alpha: 0),
          Colors.black.withValues(alpha: .08),
          Colors.black.withValues(alpha: edge + .05),
        ],
        const [0, .18, .38, .55, .8, 1],
      ),
  );
  if (material == FasilMaterial.velvet) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s.width / 2, s.height * .3),
          s.height * .5,
          [
            Colors.white.withValues(alpha: night ? .08 : .16),
            Colors.transparent,
          ],
        ),
    );
  }
  // Shade where it comes out from under the frame, and towards its end.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, s.height),
        [
          Colors.black.withValues(alpha: .4),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: .18),
        ],
        [0, math.min(.25, 14 / s.height), .7, 1],
      ),
  );
  // Stitching along both edges (not on velvet, nor a folded stub).
  if (material != FasilMaterial.velvet && !folded && s.height > 40) {
    final stitch = Paint()
      ..color = Colors.white.withValues(alpha: night ? .22 : .35)
      ..strokeWidth = 1;
    final end = s.height - math.min(s.width * 0.7, s.height * 0.3) - 6;
    for (final x in [3.0, s.width - 3]) {
      for (var y = 4.0; y < end; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3, end)), stitch);
      }
    }
  }
  canvas.restore();
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({
    required this.color,
    required this.material,
    required this.night,
    required this.folded,
  });

  final Color color;
  final FasilMaterial material;
  final bool night;
  final bool folded;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(
    _ribbonPicture(
      size: size,
      color: color,
      material: material,
      night: night,
      folded: folded,
    ),
  );

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.color != color ||
      old.material != material ||
      old.night != night ||
      old.folded != folded;
}

class _TasselPainter extends CustomPainter {
  const _TasselPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    // A gold cap, then threads fanning out.
    final cap = Rect.fromLTWH(s.width * .25, 0, s.width * .5, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cap, const Radius.circular(2)),
      Paint()..color = const Color(0xFFC9A24A),
    );
    final thread = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final t = i / 6;
      thread.color = i.isEven ? color : Color.lerp(color, Colors.black, .3)!;
      canvas.drawLine(
        Offset(s.width * (.35 + .3 * t), 5),
        Offset(s.width * t, s.height),
        thread,
      );
    }
  }

  @override
  bool shouldRepaint(_TasselPainter old) => old.color != color;
}

/// A fabric ribbon [length] long, with the fasil's name down it.
class FasilRibbon extends StatelessWidget {
  const FasilRibbon({
    super.key,
    required this.mark,
    required this.look,
    required this.length,
    this.width,
    this.folded = false,
    this.showLabel = true,
  });

  final FasilMark mark;
  final FasilLook look;
  final double length;
  final double? width;

  /// A short faded stub: a fasil on another page.
  final bool folded;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final w = width ?? look.ribbonWidth;
    final tassel = look.tassel && !folded && length > 80;
    Widget ribbon = SizedBox(
      width: w,
      height: length + (tassel ? 26 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: w,
            height: length,
            child: CustomPaint(
              painter: _RibbonPainter(
                color: mark.color,
                material: look.material,
                night: look.night,
                folded: folded,
              ),
            ),
          ),
          if (showLabel && !folded && length > 90)
            Positioned(
              top: 30,
              left: 0,
              width: w,
              height: math.min(length - 50, 150),
              child: RotatedBox(
                quarterTurns: 1,
                child: Center(
                  child: Text(
                    mark.name,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: fasilLabelColor(mark.color),
                      fontSize: look.labelSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5,
                      height: 1,
                      shadows: const [
                        Shadow(color: Color(0x80000000), blurRadius: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (tassel)
            Positioned(
              top: length - math.min(w * .7, length * .3) - 2,
              left: w / 2 - 7,
              width: 14,
              height: 28,
              child: CustomPaint(painter: _TasselPainter(mark.color)),
            ),
        ],
      ),
    );
    if (folded) {
      ribbon = Opacity(
        opacity: .6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_desaturate),
          child: ribbon,
        ),
      );
    }
    return ribbon;
  }
}

/// 60% saturation.
const _desaturate = <double>[
  .69, .29, .03, 0, 0, //
  .09, .89, .03, 0, 0, //
  .09, .29, .63, 0, 0, //
  0, 0, 0, 1, 0, //
];

// ---------------------------------------------------------------------------
// The tab
// ---------------------------------------------------------------------------

/// The die-cut card as it hangs in the book: the straight cut edge at the
/// top (tucked under the page's edge), the dome hanging down.
Path tabPath(Size s) => _hanging(_tabUp(s), s);

/// Turns a dome-up outline over, top to bottom.
Path _hanging(Path p, Size s) => p.transform(
  (Matrix4.identity()
        ..translateByDouble(0, s.height, 0, 1)
        ..scaleByDouble(1, -1, 1, 1))
      .storage,
);

/// The die-cut card dome up: straight sides and a dome, in a 100 × 160 box.
Path _tabUp(Size s) {
  final x = s.width / 100, y = s.height / 160;
  return Path()
    ..moveTo(4 * x, 160 * y)
    ..lineTo(4 * x, 60 * y)
    ..quadraticBezierTo(4 * x, 30 * y, 22 * x, 22 * y)
    ..quadraticBezierTo(34 * x, 4 * y, 50 * x, 4 * y)
    ..quadraticBezierTo(66 * x, 4 * y, 78 * x, 22 * y)
    ..quadraticBezierTo(96 * x, 30 * y, 96 * x, 60 * y)
    ..lineTo(96 * x, 160 * y)
    ..close();
}

Path _tabInline(Size s) {
  final x = s.width / 100, y = s.height / 160;
  return Path()
    ..moveTo(14 * x, 160 * y)
    ..lineTo(14 * x, 62 * y)
    ..quadraticBezierTo(14 * x, 38 * y, 30 * x, 30 * y)
    ..quadraticBezierTo(40 * x, 14 * y, 50 * x, 14 * y)
    ..quadraticBezierTo(60 * x, 14 * y, 70 * x, 30 * y)
    ..quadraticBezierTo(86 * x, 38 * y, 86 * x, 62 * y)
    ..lineTo(86 * x, 160 * y);
}

class _TabPainter extends CustomPainter {
  const _TabPainter({required this.color, required this.night});

  final Color color;
  final bool night;

  @override
  void paint(Canvas canvas, Size s) {
    final path = tabPath(s);
    if (night) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(color, Colors.white, .4)!.withValues(alpha: .3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    } else {
      canvas.drawShadow(path.shift(const Offset(0, 2)), Colors.black, 4, false);
    }
    canvas.drawPath(path, Paint()..color = color);
    final light = color.computeLuminance() > .55;
    canvas.drawPath(
      _hanging(_tabInline(s), s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = light
            ? const Color(0x804F3714)
            : Colors.white.withValues(alpha: night ? .4 : .6),
    );
  }

  @override
  bool shouldRepaint(_TabPainter old) =>
      old.color != color || old.night != night;
}

class _TabShadePainter extends CustomPainter {
  const _TabShadePainter(this.night);

  final bool night;

  @override
  void paint(Canvas canvas, Size s) => canvas.drawPath(
    tabPath(s),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(s.width, 0),
        [
          Colors.black.withValues(alpha: .18),
          Colors.white.withValues(alpha: night ? .05 : .12),
          Colors.black.withValues(alpha: .2),
        ],
        const [0, .35, 1],
      ),
  );

  @override
  bool shouldRepaint(_TabShadePainter old) => old.night != night;
}

/// A die-cut card tab slipped into the book: cut edge at the top, the
/// ornamented dome hanging down, the fasil's name upright on the card.
class FasilTab extends StatelessWidget {
  const FasilTab({
    super.key,
    required this.mark,
    required this.look,
    this.width,
    this.folded = false,
  });

  final FasilMark mark;
  final FasilLook look;
  final double? width;
  final bool folded;

  @override
  Widget build(BuildContext context) {
    final w = width ?? look.tabWidth;
    final h = w * 1.6;
    final light = mark.color.computeLuminance() > .55;
    Widget tab = SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TabPainter(color: mark.color, night: look.night),
            ),
          ),
          // The ornament: the grey medallion multiplied by the card's line
          // colour, kept to the dome.
          Positioned(
            left: w * .14,
            bottom: h * .1,
            width: w * .72,
            height: w * .72,
            child: SvgPicture.asset(
              fasilOrnamentAsset,
              colorFilter: ColorFilter.mode(
                light
                    ? const Color(0x804F3714)
                    : Colors.white.withValues(alpha: look.night ? .4 : .55),
                BlendMode.modulate,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _TabShadePainter(look.night)),
          ),
          if (!folded)
            Positioned(
              left: w * .1,
              right: w * .1,
              top: h * .2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  mark.name,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'ArefRuqaa',
                    fontSize: w * (look.elderly ? .3 : .27),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: fasilLabelColor(mark.color),
                    shadows: [
                      Shadow(
                        color: light
                            ? const Color(0x33FFFFFF)
                            : const Color(0x40000000),
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (folded) {
      tab = Opacity(
        opacity: .6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_desaturate),
          child: tab,
        ),
      );
    }
    return tab;
  }
}

// ---------------------------------------------------------------------------
// The entrance
// ---------------------------------------------------------------------------

/// Drops a ribbon into place with a soft settle, or slides a tab down, the
/// first time a just-placed fasil is shown. Still with less motion.
class FasilEntrance extends StatefulWidget {
  const FasilEntrance({
    super.key,
    required this.mark,
    required this.look,
    required this.child,
  });

  final FasilMark mark;
  final FasilLook look;
  final Widget child;

  @override
  State<FasilEntrance> createState() => _FasilEntranceState();
}

class _FasilEntranceState extends State<FasilEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.look.motion && _takeEntrance(widget.mark)) {
      _c = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: widget.look.style == FasilStyle.ribbon ? 650 : 520,
        ),
      )..forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    final ribbon = widget.look.style == FasilStyle.ribbon;
    return AnimatedBuilder(
      animation: c,
      child: widget.child,
      builder: (context, child) {
        final t = c.value;
        if (ribbon) {
          // Falls, overshoots a little, swings and settles.
          final y = Curves.easeOutBack.transform(t);
          final swing = math.sin(t * math.pi * 3) * (1 - t) * .06;
          return ClipRect(
            clipper: const _BelowTop(),
            child: FractionalTranslation(
              translation: Offset(0, y - 1),
              child: Transform.rotate(
                angle: swing,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          );
        }
        // A card slipped in from under the top edge: it slides down.
        final y = Curves.easeOutBack.transform(t);
        return ClipRect(
          clipper: const _BelowTop(),
          child: Opacity(
            opacity: Curves.easeOut.transform(math.min(1, t * 2)),
            child: FractionalTranslation(
              translation: Offset(0, -(1 - y) * .6),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Clips nothing below the top edge: the ribbon comes out from under it.
class _BelowTop extends CustomClipper<Rect> {
  const _BelowTop();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-200, 0, size.width + 200, size.height + 200);

  @override
  bool shouldReclip(_BelowTop old) => false;
}

// ---------------------------------------------------------------------------
// On the page
// ---------------------------------------------------------------------------

/// A bookmark that takes a tap and a long press, with a target of at least
/// [FasilLook.target].
class _Touchable extends StatelessWidget {
  const _Touchable({
    required this.mark,
    required this.look,
    required this.child,
    this.onLongPress,
  });

  final FasilMark mark;
  final FasilLook look;
  final Widget child;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (onLongPress == null) return child;
    return Semantics(
      button: true,
      label: mark.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: look.target,
            minHeight: look.target,
          ),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    );
  }
}

/// The fawasil on one page, over it: a ribbon hanging from the top on the
/// page's outer side (or down its outer edge), or a tab hanging from it. In
/// focus mode a short ribbon from the top edge, for either look. Part of
/// the page, so it turns with it.
class FasilPageLayer extends StatelessWidget {
  const FasilPageLayer({
    super.key,
    required this.marks,
    required this.look,
    required this.outerRight,
    required this.child,
    this.focus = false,
    this.onLongPress,
  });

  final List<FasilMark> marks;
  final FasilLook look;

  /// The page's outer edge is on the right (a right-hand page).
  final bool outerRight;
  final bool focus;
  final Widget child;
  final void Function(FasilMark)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (!look.drawn || marks.isEmpty) return child;
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight.isFinite ? box.maxHeight : 600.0;
        final children = <Widget>[child];
        for (final (i, m) in marks.indexed) {
          final step = i * (look.ribbonWidth + 6);
          Widget bookmark;
          double inset;
          double top = 0;
          if (focus) {
            bookmark = FasilRibbon(
              mark: m,
              look: look,
              length: math.max(56, h * .13),
              width: look.ribbonWidth * .85,
              showLabel: look.elderly,
            );
            inset = 4 + step;
          } else if (look.style == FasilStyle.ribbon) {
            final side = look.place == FasilPlace.side;
            bookmark = FasilRibbon(
              mark: m,
              look: look,
              length: h * (side ? .62 : .42),
            );
            inset = (side ? 2 : 10) + step;
          } else if (look.place == FasilPlace.side) {
            bookmark = RotatedBox(
              quarterTurns: outerRight ? 1 : 3,
              // Only the dome shows past the edge, over the frame.
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: .72,
                  child: FasilTab(
                    mark: m,
                    look: look,
                    width: look.tabWidth * .7,
                  ),
                ),
              ),
            );
            inset = 0;
            top = h * .14 + i * (look.tabWidth * .7 + 8);
          } else {
            bookmark = FasilTab(mark: m, look: look);
            inset = 8 + i * (look.tabWidth + 4);
          }
          final placed = _Touchable(
            mark: m,
            look: look,
            onLongPress: onLongPress == null ? null : () => onLongPress!(m),
            child: FasilEntrance(
              key: ValueKey('fasil-entrance-${m.id}'),
              mark: m,
              look: look,
              child: bookmark,
            ),
          );
          children.add(
            Positioned(
              key: ValueKey('fasil-${m.id}'),
              top: top,
              right: outerRight ? inset : null,
              left: outerRight ? null : inset,
              child: placed,
            ),
          );
        }
        return Stack(clipBehavior: Clip.hardEdge, children: children);
      },
    );
  }
}

/// A spread's fawasil in its spine: ribbons lying in the gutter, fanned a
/// little, their tails hanging to the foot; tabs hanging from its head on
/// their own page's side.
class FasilSpineLayer extends StatelessWidget {
  const FasilSpineLayer({
    super.key,
    required this.right,
    required this.left,
    required this.look,
    required this.child,
    this.onLongPress,
  });

  /// On the right-hand page, and on the left.
  final List<FasilMark> right;
  final List<FasilMark> left;
  final FasilLook look;
  final Widget child;
  final void Function(FasilMark)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (!look.drawn || (right.isEmpty && left.isEmpty)) return child;
    return LayoutBuilder(
      builder: (context, box) {
        final cx = box.maxWidth / 2;
        final h = box.maxHeight;
        final children = <Widget>[child];
        final all = [
          for (final m in right) (m, true),
          for (final m in left) (m, false),
        ];
        for (final (i, (m, onRight)) in all.indexed) {
          Widget bookmark;
          double x;
          if (look.style == FasilStyle.ribbon) {
            final w = look.ribbonWidth * .9;
            bookmark = Transform.rotate(
              angle: (onRight ? 1 : -1) * (.012 + i * .008),
              alignment: Alignment.topCenter,
              child: FasilRibbon(
                mark: m,
                look: look,
                length: h - (look.tassel ? 30 : 6),
                width: w,
              ),
            );
            x = cx - w / 2 + (onRight ? 1 : -1) * (2 + i * 5);
          } else {
            final w = look.tabWidth * .9;
            bookmark = FasilTab(mark: m, look: look, width: w);
            final n = all.where((e) => e.$2 == onRight).toList().indexOf((
              m,
              onRight,
            ));
            x = onRight ? cx + 6 + n * (w + 4) : cx - 6 - w - n * (w + 4);
          }
          children.add(
            Positioned(
              key: ValueKey('fasil-${m.id}'),
              top: 0,
              left: x,
              child: _Touchable(
                mark: m,
                look: look,
                onLongPress: onLongPress == null ? null : () => onLongPress!(m),
                child: FasilEntrance(
                  key: ValueKey('fasil-entrance-${m.id}'),
                  mark: m,
                  look: look,
                  child: bookmark,
                ),
              ),
            ),
          );
        }
        return Stack(clipBehavior: Clip.hardEdge, children: children);
      },
    );
  }
}

/// The fawasil kept on other pages, folded at the top edge: short faded
/// stubs. A tap goes to its page; a long press opens its actions.
class FoldedFawasil extends StatelessWidget {
  const FoldedFawasil({
    super.key,
    required this.marks,
    required this.look,
    required this.onTap,
    required this.onLongPress,
    required this.semanticLabel,
  });

  final List<FasilMark> marks;
  final FasilLook look;
  final void Function(FasilMark) onTap;
  final void Function(FasilMark) onLongPress;
  final String Function(FasilMark) semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (!look.drawn || marks.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in marks)
          Semantics(
            key: ValueKey('folded-${m.id}'),
            button: true,
            label: semanticLabel(m),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(m),
              onLongPress: () => onLongPress(m),
              child: SizedBox(
                width: math.max(look.target * .62, look.ribbonWidth + 8),
                height: look.target,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: look.style == FasilStyle.ribbon
                      ? FasilRibbon(
                          mark: m,
                          look: look,
                          length: look.elderly ? 52 : 40,
                          width: look.ribbonWidth * .8,
                          folded: true,
                        )
                      : ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: .55,
                            child: FasilTab(
                              mark: m,
                              look: look,
                              width: look.ribbonWidth + 6,
                              folded: true,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
