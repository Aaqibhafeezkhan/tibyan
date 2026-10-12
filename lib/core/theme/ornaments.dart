// Ornaments of the interface styles: original vector art drawn in code
// (star medallions, girih lattice, tazhib band, arches, Kaaba and dome).
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class StarPainter extends CustomPainter {
  StarPainter(this.fill, this.line);
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
  bool shouldRepaint(StarPainter o) => o.fill != fill || o.line != line;
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
  bool shouldRepaint(GirihPainter o) => o.color != color || o.cell != cell;
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

class ArchBorder extends CustomPainter {
  ArchBorder(this.color, {this.spring = .42, this.inset = 6});
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
  bool shouldRepaint(ArchBorder o) => o.color != color;
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
  bool shouldRepaint(SkyPainter o) => o.color != color;
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
  bool shouldRepaint(Ring o) =>
      o.value != value || o.color != color || o.track != track;
}

/// A tazhib band: chained lozenges with dots between two gold rules.
class TazhibPainter extends CustomPainter {
  TazhibPainter(this.gold, this.dot);
  final Color gold, dot;
  @override
  void paint(Canvas canvas, Size s) {
    final g = Paint()
      ..color = gold
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset.zero, Offset(s.width, 0), g)
      ..drawLine(Offset(0, s.height), Offset(s.width, s.height), g);
    final step = s.height * 1.4;
    final fill = Paint()..color = gold;
    final d = Paint()..color = dot;
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
      canvas.drawCircle(Offset(x + step / 2, cy), s.height * .12, d);
    }
  }

  @override
  bool shouldRepaint(TazhibPainter o) => o.gold != gold || o.dot != dot;
}
