import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  /// The terminal bead: the same material, deeper.
  static BeadLook terminalOf(BeadLook l) =>
      BeadLook(Color.lerp(l.base, Colors.black, .28)!, l.shine, l.scatter * .6);

  static BeadLook of(BeadMaterial m) => switch (m) {
    BeadMaterial.amber => const BeadLook(Color(0xFFC77A1C), .9, .75),
    BeadMaterial.wood => const BeadLook(Color(0xFF6E4326), .28, 0),
    BeadMaterial.pearl => const BeadLook(Color(0xFFE6E0D3), .75, .3),
  };
}

/// «مسبحة ثلاثية الأبعاد»: beads on a string that runs like a conveyor.
/// Each count moves the whole string down one bead: the bead at the gap
/// crosses it to the counted beads below and the next bead comes down into
/// its place. The beads are an endless loop, with the terminal bead at each
/// round's end. A drag follows the finger; past 40% of the way the bead
/// goes over (a short ease-out and a light knock on the bead below), short
/// of that it eases back. Taps and quick flicks queue: none is lost.
class MisbahaView extends StatefulWidget {
  const MisbahaView({
    super.key,
    required this.material,
    required this.render,
    required this.onCount,
    this.count = 0,
    this.roundSize,
    this.animate = true,
  });

  final BeadMaterial material;
  final MisbahaRender render;
  final VoidCallback onCount;

  /// The counter's count in the round: counts made elsewhere (the volume
  /// buttons, the keyboard) move the string too.
  final int count;

  /// The beads to a round (the target); the terminal bead ends each.
  final int? roundSize;

  /// False under reduce-motion: each count moves the string at once, and
  /// it does not sway.
  final bool animate;

  @override
  State<MisbahaView> createState() => _MisbahaViewState();
}

/// Where a pull past this share of the way goes over on release.
const misbahaCommitShare = .4;

class _MisbahaViewState extends State<MisbahaView>
    with TickerProviderStateMixin {
  /// The string's place, in beads: bead `k` is at the gap when it is `k`.
  late final _phase = AnimationController.unbounded(vsync: this);

  /// The string's slow sway (true 3D only).
  late final _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  /// Counts the string has been asked to move: where it comes to rest.
  int _k = 0;

  /// The counter's count when the string's bead 0 was at the gap.
  late int _count0;

  /// The gap's length on screen, for the drag.
  double _travel = 1;
  bool _dragging = false;

  static ui.FragmentProgram? _program;
  static bool _loading = false;

  int get _modulus => widget.roundSize ?? (1 << 30);

  @override
  void initState() {
    super.initState();
    _count0 = widget.count;
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
    // Counts made elsewhere move the string; anything else (a reset, a
    // new dhikr or target) only re-numbers the beads.
    final m = _modulus;
    final expected = (_count0 + _k) % m;
    final ahead = (widget.count - expected) % m;
    if (widget.count == expected % m) return;
    if (widget.roundSize == old.roundSize && ahead > 0 && ahead <= 8) {
      for (var i = 0; i < ahead; i++) {
        _advance(count: false);
      }
    } else {
      _count0 = widget.count - _k;
    }
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
    _phase.dispose();
    _sway.dispose();
    super.dispose();
  }

  /// One bead over: the string moves to its next rest. With [count] the
  /// counter counts too (a pull or a tap here).
  void _advance({bool count = true}) {
    _k++;
    if (count) widget.onCount();
    if (!widget.animate) {
      _phase.value = _k.toDouble();
      return;
    }
    // Far behind (fast flicks): catch up to one bead before the last.
    if (_k - _phase.value > 3) _phase.value = _k - 1.0;
    unawaited(
      _phase.animateTo(
        _k.toDouble(),
        duration: const Duration(milliseconds: 170),
        curve: const _KnockCurve(),
      ),
    );
  }

  void _dragStart() {
    _dragging = true;
    _phase.stop();
    _phase.value = _k.toDouble();
  }

  void _dragUpdate(double dy) {
    if (!_dragging) return;
    _phase.value = (_phase.value + dy / _travel).clamp(_k.toDouble(), _k + 1.0);
    // A pull all the way goes over without waiting for the release, and a
    // new pull can start on the next bead.
    if (_phase.value >= _k + 1) {
      _advance();
    }
  }

  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final share = _phase.value - _k;
    if (share >= misbahaCommitShare || velocity / _travel > 3) {
      _advance();
    } else if (widget.animate) {
      unawaited(
        _phase.animateTo(
          _k.toDouble(),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _phase.value = _k.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        _travel = widget.render == MisbahaRender.real
            ? RealMisbahaPainter.travel(size)
            : SuggestedMisbahaPainter.travel(size);
        final look = BeadLook.of(widget.material);
        final string = Theme.of(context).colorScheme.onSurfaceVariant;
        final m = _modulus;
        // Bead `i` is counted as the round's last (the terminal bead).
        bool terminal(int i) =>
            widget.roundSize != null && (_count0 + i + 1) % m == 0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          onVerticalDragStart: (_) => _dragStart(),
          onVerticalDragUpdate: (d) => _dragUpdate(d.delta.dy),
          onVerticalDragEnd: (d) => _dragEnd(d.velocity.pixelsPerSecond.dy),
          onVerticalDragCancel: () => _dragEnd(0),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: widget.render == MisbahaRender.real
                  ? RealMisbahaPainter(
                      phase: _phase,
                      sway: _sway,
                      look: look,
                      program: _program,
                      string: string,
                      terminal: terminal,
                    )
                  : SuggestedMisbahaPainter(
                      phase: _phase,
                      look: look,
                      string: string,
                      terminal: terminal,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// An ease-out that runs a little past the end and settles back: the bead
/// knocking lightly on the one below.
class _KnockCurve extends Curve {
  const _KnockCurve();

  @override
  double transformInternal(double t) {
    final out = Curves.easeOutCubic.transform(math.min(1, t / .78));
    if (t <= .78) return out * 1.04;
    final back = (t - .78) / .22;
    return 1.04 - .04 * Curves.easeInOut.transform(back);
  }
}

/// Whether bead `i` of the endless string is the terminal bead.
typedef TerminalBead = bool Function(int i);

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
    required this.phase,
    required this.look,
    required this.string,
    required this.terminal,
  }) : super(repaint: phase);

  /// The string's place, in beads (see [MisbahaView]).
  final Animation<double> phase;
  final BeadLook look;
  final Color string;
  final TerminalBead terminal;

  static const upper = 7, lower = 5;

  static double radius(Size s) =>
      math.min(s.width * .1, s.height / ((upper + lower) * 2 + 5.5));

  /// Pixels from the bead's place at the gap to the counted beads.
  static double travel(Size s) {
    final r = radius(s);
    final step = r * 1.96;
    final top = s.height * .04 + r + (upper - 1) * step;
    final bottomTop = s.height * .96 - r - (lower - 1) * step;
    return math.max(1, bottomTop - step - top);
  }

  /// Where along the string a bead `u` beads past the gap is: the beads
  /// to come above (u <= 0), across the gap (0..1), the counted below.
  static double yAt(Size s, double u) {
    final r = radius(s);
    final step = r * 1.96;
    final atGap = s.height * .04 + r + (upper - 1) * step;
    final g = travel(s);
    if (u <= 0) return atGap + u * step;
    if (u < 1) return atGap + u * g;
    return atGap + g + (u - 1) * step;
  }

  double _x(Size s, double y) =>
      s.width / 2 + s.width * .06 * math.sin(math.pi * y / s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius(size);
    final p = phase.value;
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
    final first = p.floor() - lower - 2;
    final last = p.floor() + upper + 2;
    for (var i = first; i <= last; i++) {
      final y = yAt(size, p - i);
      if (y < -2 * r || y > size.height + 2 * r) continue;
      final end = terminal(i);
      paintShadedBead(
        canvas,
        Offset(_x(size, y), y),
        end ? r * 1.22 : r,
        end ? BeadLook.terminalOf(look) : look,
      );
    }
  }

  @override
  bool shouldRepaint(SuggestedMisbahaPainter old) =>
      old.look != look ||
      old.string != string ||
      old.phase != phase ||
      old.terminal != terminal;
}

/// «ثلاثي الأبعاد حقيقي»: the beads are spheres on a ring in 3D space,
/// seen through a perspective camera. Each bead's place is projected, its
/// size follows its depth, the far ones are drawn first and darker, and
/// each is lit per pixel by `shaders/bead.frag` (a shaded disc where
/// shaders are not available). The pulled bead crosses the ring's gap at
/// its near side.
class RealMisbahaPainter extends CustomPainter {
  RealMisbahaPainter({
    required this.phase,
    required this.sway,
    required this.look,
    required this.string,
    required this.terminal,
    this.program,
  }) : super(repaint: Listenable.merge([phase, sway]));

  /// The string's place, in beads (see [MisbahaView]).
  final Animation<double> phase;
  final TerminalBead terminal;
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
    // A bead `u` beads past the gap: the beads to come run up and round
    // the back (u <= 0), one crosses the gap (0..1), the counted run down
    // and round. The two ends meet at the back, so the ring of [beads]
    // beads (u in [-12, 12)) turns without a seam.
    double thetaAt(double u) {
      if (u <= 0) return half - gap / 2 + u * _step;
      if (u < 1) return half - gap / 2 + u * gap;
      return half + gap / 2 + (u - 1) * _step;
    }

    final p = phase.value;
    final shown = <(double, bool)>[];
    for (var i = p.floor() - _upper - 2; i <= p.floor() + beads; i++) {
      final u = p - i;
      if (u < -(beads - 1 - _upper) || u >= _upper + 1) continue;
      shown.add((thetaAt(u), terminal(i)));
    }

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

    final placed = [for (final (t, end) in shown) (at(t), end)]
      ..sort((a, b) => a.$1.$3.compareTo(b.$1.$3));
    final program = this.program;
    while (program != null && _shaders.length < beads + 2) {
      _shaders.add(program.fragmentShader());
    }
    var i = 0;
    for (final ((p, k, z), end) in placed) {
      final r = bead * k * (end ? 1.22 : 1);
      final look = end ? BeadLook.terminalOf(this.look) : this.look;
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
      old.phase != phase ||
      old.terminal != terminal;
}
