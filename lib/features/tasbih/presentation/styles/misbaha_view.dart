import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../tasbih_settings.dart';

/// A bead material's colour and how it takes light.
@immutable
class BeadLook {
  const BeadLook(this.base, this.shine, this.scatter);

  final Color base;

  /// Specular strength, 0..1.
  final double shine;

  /// Light passing through the bead (amber, pearl), 0..1.
  final double scatter;

  static BeadLook of(BeadMaterial m) => switch (m) {
    BeadMaterial.amber => const BeadLook(Color(0xFFC77A1C), .9, .75),
    BeadMaterial.wood => const BeadLook(Color(0xFF6E4326), .28, 0),
    BeadMaterial.pearl => const BeadLook(Color(0xFFE6E0D3), .75, .3),
  };
}

/// «مسبحة ثلاثية الأبعاد»: beads on a string. One bead is pulled down
/// along the string to the others (a drag, or a tap that does it for the
/// reader); when it reaches them it counts. A short pull springs back.
class MisbahaView extends StatefulWidget {
  const MisbahaView({
    super.key,
    required this.material,
    required this.render,
    required this.onCount,
    this.animate = true,
  });

  final BeadMaterial material;
  final MisbahaRender render;
  final VoidCallback onCount;

  /// False under reduce-motion: the bead moves without a spring, and the
  /// string does not sway.
  final bool animate;

  @override
  State<MisbahaView> createState() => _MisbahaViewState();
}

class _MisbahaViewState extends State<MisbahaView>
    with TickerProviderStateMixin {
  /// How far the bead is along the gap: 0 with the upper beads, 1 with
  /// the lower.
  late final _pull = AnimationController.unbounded(vsync: this);

  /// The string's slow sway (true 3D only).
  late final _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  /// The gap's length on screen, for the drag.
  double _travel = 1;
  bool _landing = false;

  static ui.FragmentProgram? _program;
  static bool _loading = false;

  @override
  void initState() {
    super.initState();
    _syncSway();
    if (!_loading) {
      _loading = true;
      ui.FragmentProgram.fromAsset('shaders/bead.frag').then((p) {
        _program = p;
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  @override
  void didUpdateWidget(MisbahaView old) {
    super.didUpdateWidget(old);
    _syncSway();
  }

  void _syncSway() {
    final on = widget.animate && widget.render == MisbahaRender.real;
    if (on && !_sway.isAnimating) {
      unawaited(_sway.repeat());
    } else if (!on && _sway.isAnimating) {
      _sway.stop();
    }
  }

  @override
  void dispose() {
    _pull.dispose();
    _sway.dispose();
    super.dispose();
  }

  Future<void> _land() async {
    if (_landing) return;
    _landing = true;
    if (widget.animate) {
      await _pull.animateTo(
        1,
        duration: Duration(
          milliseconds: (140 * (1 - _pull.value).clamp(.2, 1)).round(),
        ),
        curve: Curves.easeIn,
      );
    }
    widget.onCount();
    // The bead joins the lower ones and the next takes its place: the
    // beads look alike, so the string is drawn as before.
    _pull.value = 0;
    _landing = false;
  }

  void _springBack(double velocity) {
    if (!widget.animate) {
      _pull.value = 0;
      return;
    }
    _pull.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 22),
        _pull.value,
        0,
        velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        _travel = widget.render == MisbahaRender.real
            ? RealMisbahaPainter.travel(size)
            : SuggestedMisbahaPainter.travel(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _land,
          onVerticalDragStart: (_) => _pull.stop(),
          onVerticalDragUpdate: (d) {
            if (_landing) return;
            _pull.value = (_pull.value + d.delta.dy / _travel).clamp(0, 1);
            if (_pull.value >= 1) unawaited(_land());
          },
          onVerticalDragEnd: (d) {
            if (_landing) return;
            final v = d.velocity.pixelsPerSecond.dy / _travel;
            if (_pull.value > .5 || v > 2.5) {
              unawaited(_land());
            } else {
              _springBack(v);
            }
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: widget.render == MisbahaRender.real
                  ? RealMisbahaPainter(
                      pull: _pull,
                      sway: _sway,
                      look: BeadLook.of(widget.material),
                      program: _program,
                      string: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : SuggestedMisbahaPainter(
                      pull: _pull,
                      look: BeadLook.of(widget.material),
                      string: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws a bead as a flat disc shaded to look round: a radial gradient lit
/// from [light] (a direction on screen, y down), a glow through it, a
/// specular spot and a soft shadow.
void paintShadedBead(
  Canvas canvas,
  Offset c,
  double r,
  BeadLook look, {
  Offset light = const Offset(-.45, -.6),
  double fade = 0,
  bool shadow = true,
}) {
  if (shadow) {
    canvas.drawCircle(
      c + Offset(-light.dx * r * .35, -light.dy * r * .45),
      r * .98,
      Paint()
        ..color = Colors.black.withValues(alpha: .28 * (1 - fade))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .35),
    );
  }
  final base = Color.lerp(look.base, Colors.black, fade * .5)!;
  final hi = Color.lerp(base, Colors.white, .45 * look.shine + .1)!;
  final dark = Color.lerp(base, Colors.black, .62)!;
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: Alignment(light.dx * .7, light.dy * .7),
        radius: 1.15,
        colors: [hi, base, dark],
        stops: const [0, .5, 1],
      ).createShader(rect),
  );
  if (look.scatter > 0) {
    // Light through the bead, gathering on the side away from the light.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment(-light.dx * .55, -light.dy * .55),
          radius: .7,
          colors: [
            Color.lerp(
              base,
              Colors.white,
              .3,
            )!.withValues(alpha: .45 * look.scatter),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }
  // The specular spot.
  final spot = Rect.fromCenter(
    center: c + Offset(light.dx * r * .5, light.dy * r * .5),
    width: r * .46,
    height: r * .3,
  );
  canvas.drawOval(
    spot,
    Paint()
      ..color = Colors.white.withValues(alpha: .25 + .6 * look.shine)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .06),
  );
}

/// «إيحاء ثلاثي الأبعاد»: shaded beads on a gently curved string, the
/// upper ones together at the top, the counted ones at the bottom, and
/// the gap between them that the pulled bead crosses.
class SuggestedMisbahaPainter extends CustomPainter {
  SuggestedMisbahaPainter({
    required this.pull,
    required this.look,
    required this.string,
  }) : super(repaint: pull);

  final Animation<double> pull;
  final BeadLook look;
  final Color string;

  static const upper = 7, lower = 5;

  static double radius(Size s) =>
      math.min(s.width * .1, s.height / ((upper + lower) * 2 + 5.5));

  /// Pixels from the pulled bead's place to the lower beads.
  static double travel(Size s) {
    final r = radius(s);
    final step = r * 1.96;
    final top = s.height * .04 + r + (upper - 1) * step;
    final bottomTop = s.height * .96 - r - (lower - 1) * step;
    return math.max(1, bottomTop - step - top);
  }

  double _x(Size s, double y) =>
      s.width / 2 + s.width * .06 * math.sin(math.pi * y / s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius(size);
    final step = r * 1.96;
    final y0 = size.height * .04 + r;
    final active = y0 + (upper - 1) * step + pull.value * travel(size);
    final ys = [
      for (var k = 0; k < upper - 1; k++) y0 + k * step,
      active,
      for (var j = lower - 1; j >= 0; j--) size.height * .96 - r - j * step,
    ];
    final path = Path()..moveTo(_x(size, 0), 0);
    for (var y = 0.0; y <= size.height; y += 6) {
      path.lineTo(_x(size, y), y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, r * .08)
        ..color = string.withValues(alpha: .55),
    );
    for (final y in ys) {
      paintShadedBead(canvas, Offset(_x(size, y), y), r, look);
    }
  }

  @override
  bool shouldRepaint(SuggestedMisbahaPainter old) =>
      old.look != look || old.string != string || old.pull != pull;
}

/// «ثلاثي الأبعاد حقيقي»: the beads are spheres on a ring in 3D space,
/// seen through a perspective camera. Each bead's place is projected, its
/// size follows its depth, the far ones are drawn first and darker, and
/// each is lit per pixel by `shaders/bead.frag` (a shaded disc where
/// shaders are not available). The pulled bead crosses the ring's gap at
/// its near side.
class RealMisbahaPainter extends CustomPainter {
  RealMisbahaPainter({
    required this.pull,
    required this.sway,
    required this.look,
    required this.string,
    this.program,
  }) : super(repaint: Listenable.merge([pull, sway]));

  final Animation<double> pull;
  final Animation<double> sway;
  final BeadLook look;
  final Color string;
  final ui.FragmentProgram? program;

  static const beads = 24;
  static const gap = .9;
  static final _step = (2 * math.pi - gap) / (beads - 1);
  static const _upper = 11;

  /// The light, in view space (x right, y down, z toward the eye).
  static const light = (x: -.45, y: -.62, z: .64);

  static final _shaders = <ui.FragmentShader>[];

  static double _ringRadius(Size s) => math.min(s.width * .36, s.height * .36);

  /// The bead's path across the gap on screen, roughly.
  static double travel(Size s) => _ringRadius(s) * gap * 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = _ringRadius(size);
    final yaw = (50 + 9 * math.sin(2 * math.pi * sway.value)) * math.pi / 180;
    final camZ = 4.2;
    final f = ring * camZ * .92;
    final centre = Offset(size.width / 2, size.height * .5);
    final bead = _step / 2.04;

    // A point of the unit ring, as (screen point, scale, depth).
    (Offset, double, double) at(double theta) {
      final x = math.sin(theta) * math.sin(yaw);
      final y = math.cos(theta);
      final z = math.sin(theta) * math.cos(yaw);
      final k = f / (camZ - z);
      return (centre + Offset(x * k, -y * k), k, z);
    }

    final half = math.pi / 2;
    final thetas = [
      half - gap / 2 + pull.value * gap,
      for (var k = 1; k <= _upper; k++) half - gap / 2 - k * _step,
      for (var j = 0; j < beads - 1 - _upper; j++) half + gap / 2 + j * _step,
    ];

    // The ground shadow under the ring.
    canvas.drawOval(
      Rect.fromCenter(
        center: centre + Offset(0, ring * 1.32),
        width: ring * 1.5,
        height: ring * .22,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: .18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ring * .08),
    );

    // The string, far half then near half around the beads.
    final far = Path(), near = Path();
    for (var i = 0; i < 96; i++) {
      final (a, _, za) = at(2 * math.pi * i / 96);
      final (b, _, zb) = at(2 * math.pi * (i + 1) / 96);
      (za + zb < 0 ? far : near)
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    final cord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, ring * .012)
      ..color = string.withValues(alpha: .5);
    canvas.drawPath(far, cord);

    final placed = [for (final t in thetas) at(t)]
      ..sort((a, b) => a.$3.compareTo(b.$3));
    final program = this.program;
    while (program != null && _shaders.length < beads) {
      _shaders.add(program.fragmentShader());
    }
    var i = 0;
    for (final (p, k, z) in placed) {
      final r = bead * k;
      final fade = ((1 - z) / 2).clamp(0.0, 1.0) * .7;
      // Soft contact shadow, away from the light.
      canvas.drawCircle(
        p + Offset(r * .3, r * .4),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: .22 * (1 - fade))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .4),
      );
      if (program == null) {
        paintShadedBead(
          canvas,
          p,
          r,
          look,
          light: Offset(light.x, light.y),
          fade: fade,
          shadow: false,
        );
      } else {
        final s = _shaders[i++];
        final c = look.base;
        s
          ..setFloat(0, p.dx)
          ..setFloat(1, p.dy)
          ..setFloat(2, r)
          ..setFloat(3, light.x)
          ..setFloat(4, light.y)
          ..setFloat(5, light.z)
          ..setFloat(6, c.r)
          ..setFloat(7, c.g)
          ..setFloat(8, c.b)
          ..setFloat(9, look.shine)
          ..setFloat(10, look.scatter)
          ..setFloat(11, fade);
        canvas.drawRect(
          Rect.fromCircle(center: p, radius: r + 1),
          Paint()..shader = s,
        );
      }
    }
    canvas.drawPath(near, cord..color = string.withValues(alpha: .25));
  }

  @override
  bool shouldRepaint(RealMisbahaPainter old) =>
      old.look != look ||
      old.string != string ||
      old.program != program ||
      old.pull != pull;
}
