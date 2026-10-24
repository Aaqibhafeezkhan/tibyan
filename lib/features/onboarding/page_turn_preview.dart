import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';

/// A tiny open book whose page turns, over and over, with [effect]: the
/// first-run chooser shows each page-turn effect with one of these.
///
/// It is a mockup, not the reader's page: two small pages of grey «lines»,
/// the second with a gold band so the turn is easy to follow. With
/// animations turned off (MediaQuery.disableAnimations) it stands still.
class PageTurnPreview extends StatefulWidget {
  const PageTurnPreview({
    super.key,
    required this.effect,
    required this.paper,
    required this.ink,
    required this.accent,
    this.width = 120,
  });

  final PageTurn effect;
  final Color paper;
  final Color ink;
  final Color accent;
  final double width;

  /// One loop: rest, turn, rest, turn back.
  static const period = Duration(milliseconds: 3200);

  @override
  State<PageTurnPreview> createState() => _PageTurnPreviewState();
}

class _PageTurnPreviewState extends State<PageTurnPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: PageTurnPreview.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = 0.35;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0 → 1 → 0 over a loop, resting at each end.
  static double _progress(double t) {
    double turn(double x) => Curves.easeInOut.transform(x.clamp(0.0, 1.0));
    if (t < .2) return 0;
    if (t < .45) return turn((t - .2) / .25);
    if (t < .7) return 1;
    if (t < .95) return 1 - turn((t - .7) / .25);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * .72;
    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: h,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _book(_progress(_c.value), Size(w / 2, h)),
        ),
      ),
    );
  }

  Widget _page(Size size, {required bool second, required bool left}) =>
      SizedBox.fromSize(
        size: size,
        child: CustomPaint(
          painter: _MiniPagePainter(
            paper: widget.paper,
            ink: widget.ink,
            accent: widget.accent,
            second: second,
            left: left,
          ),
        ),
      );

  /// A spread: the left page stays; the right page turns over to show the
  /// next one (an Arabic book opens to the right, its pages turn leftward
  /// to rightward — here the turning leaf moves across the spine).
  Widget _book(double p, Size half) {
    final under = _page(half, second: true, left: false);
    final over = _page(half, second: false, left: false);
    final left = _page(half, second: false, left: true);
    final Widget right = switch (widget.effect) {
      PageTurn.fade => Stack(
        children: [
          over,
          Opacity(opacity: p, child: under),
        ],
      ),
      PageTurn.normal => ClipRect(
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(-half.width * p, 0),
              child: over,
            ),
            Transform.translate(
              offset: Offset(half.width * (1 - p), 0),
              child: under,
            ),
          ],
        ),
      ),
      PageTurn.curl => Stack(
        clipBehavior: Clip.none,
        children: [
          under,
          if (p < .5)
            Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.004)
                ..rotateY(-math.pi * p),
              child: _shade(over, p * 1.2),
            ),
        ],
      ),
      PageTurn.bend => Stack(
        clipBehavior: Clip.none,
        children: [
          under,
          if (p < .98)
            Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(-math.pi * .5 * p)
                ..scaleByDouble(1 - .45 * p, 1, 1, 1),
              child: _shade(over, p),
            ),
        ],
      ),
      PageTurn.fold => Stack(
        clipBehavior: Clip.none,
        children: [
          under,
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1 - p,
              child: _shade(over, p * .6),
            ),
          ),
          // The folded-back flap at the edge of the fold.
          if (p > 0 && p < 1)
            Positioned(
              left: half.width * (1 - p) - half.width * .18 * (1 - p),
              top: 0,
              bottom: 0,
              width: half.width * .18 * (1 - p),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.paper,
                      Color.lerp(widget.paper, widget.ink, .25)!,
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: widget.ink.withValues(alpha: .18),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            left,
            Container(width: .8, color: widget.ink.withValues(alpha: .25)),
            Expanded(child: right),
          ],
        ),
      ),
    );
  }

  /// The turning leaf darkens a little as it lifts.
  Widget _shade(Widget page, double amount) => Stack(
    children: [
      page,
      Positioned.fill(
        child: ColoredBox(
          color: widget.ink.withValues(alpha: .18 * amount.clamp(0.0, 1.0)),
        ),
      ),
    ],
  );
}

class _MiniPagePainter extends CustomPainter {
  _MiniPagePainter({
    required this.paper,
    required this.ink,
    required this.accent,
    required this.second,
    required this.left,
  });

  final Color paper;
  final Color ink;
  final Color accent;
  final bool second;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final pad = size.width * .14;
    final line = Paint()
      ..color = ink.withValues(alpha: .38)
      ..strokeWidth = math.max(1, size.height * .022)
      ..strokeCap = StrokeCap.round;
    const rows = 7;
    final top = size.height * .14;
    final step = (size.height - 2 * top) / (rows - 1);
    for (var i = 0; i < rows; i++) {
      final y = top + step * i;
      if (second && i == 1) {
        // The next page opens on a surah band, so the turn shows.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              pad,
              y - step * .35,
              size.width - pad,
              y + step * .35,
            ),
            Radius.circular(step * .2),
          ),
          Paint()..color = accent.withValues(alpha: .55),
        );
        continue;
      }
      // Lines of slightly different lengths, right-aligned like Arabic.
      final short =
          (i * 37 +
                  (left
                      ? 11
                      : second
                      ? 23
                      : 5)) %
              5 ==
          0;
      final start = short ? size.width * .42 : pad;
      canvas.drawLine(Offset(start, y), Offset(size.width - pad, y), line);
    }
  }

  @override
  bool shouldRepaint(_MiniPagePainter old) =>
      old.paper != paper ||
      old.ink != ink ||
      old.accent != accent ||
      old.second != second ||
      old.left != left;
}
