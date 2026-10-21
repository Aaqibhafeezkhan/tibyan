import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/interface_style.dart';
import '../../../../l10n/app_localizations.dart';

/// «زر كبير»: one large round button that sinks under the finger and
/// springs back, with the round's progress as a ring around it.
class PressButtonView extends StatefulWidget {
  const PressButtonView({
    super.key,
    required this.onCount,
    required this.progress,
    this.large = false,
    this.animate = true,
  });

  final VoidCallback onCount;

  /// The round's progress, 0..1.
  final double progress;

  /// Elderly mode: a larger button.
  final bool large;
  final bool animate;

  @override
  State<PressButtonView> createState() => _PressButtonViewState();
}

class _PressButtonViewState extends State<PressButtonView> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final d = math.min(
          widget.large ? 280.0 : 240.0,
          math.min(box.maxWidth, box.maxHeight) - 40,
        );
        final travel = widget.animate ? 12.0 : 0.0;
        return Center(
          child: SizedBox.square(
            dimension: d + 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: ProgressRingPainter(
                      progress: widget.progress,
                      track: look.line,
                      fill: look.accent,
                    ),
                  ),
                ),
                GestureDetector(
                  onTapDown: (_) => setState(() => _down = true),
                  onTapCancel: () => setState(() => _down = false),
                  onTapUp: (_) {
                    setState(() => _down = false);
                    widget.onCount();
                  },
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: widget.animate ? (_down ? 60 : 220) : 0,
                    ),
                    curve: _down ? Curves.easeOut : Curves.elasticOut,
                    transform: Matrix4.translationValues(
                      0,
                      _down ? travel : 0,
                      0,
                    ),
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-.3, -.4),
                        colors: [
                          Color.lerp(look.control, Colors.white, .22)!,
                          look.control,
                          Color.lerp(look.control, Colors.black, .25)!,
                        ],
                        stops: const [0, .6, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color.lerp(
                            look.control,
                            Colors.black,
                            .6,
                          )!.withValues(alpha: .35),
                          blurRadius: _down ? 6 : 22,
                          offset: Offset(0, _down ? 3 : 14),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l.tasbihCountAction,
                      style: TextStyle(
                        color: look.onControl,
                        fontSize: widget.large ? 34 : 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The round's progress as a ring; full when a round closes.
class ProgressRingPainter extends CustomPainter {
  ProgressRingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    this.width = 5,
  });

  final double progress;
  final Color track, fill;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

/// The electronic counter's large key.
const lcdKey = ValueKey('tasbih-lcd-key');

/// The electronic counter's small reset (R) key.
const lcdResetKey = ValueKey('tasbih-lcd-reset-key');

/// «عداد إلكتروني»: a hand counter. A seven-segment display (Latin digits
/// on purpose, as on the device), a large metal key that counts, and a
/// small R key that resets the round on a tap or long press.
class LcdCounterView extends StatefulWidget {
  const LcdCounterView({
    super.key,
    required this.count,
    required this.rounds,
    required this.onCount,
    required this.onReset,
    this.animate = true,
  });

  final int count;
  final int rounds;
  final VoidCallback onCount;
  final VoidCallback onReset;
  final bool animate;

  @override
  State<LcdCounterView> createState() => _LcdCounterViewState();
}

class _LcdCounterViewState extends State<LcdCounterView> {
  bool _down = false;
  bool _rDown = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(300.0, box.maxWidth - 32);
        final h = math.min(w * 1.25, box.maxHeight - 16);
        final key = math.min(w * .5, h * .42);
        return Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w * .3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: look.night
                    ? const [Color(0xFF3A3F45), Color(0xFF1F2327)]
                    : const [Color(0xFF59606A), Color(0xFF2E3338)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(height: h * .1),
                // The display.
                Container(
                  width: w * .7,
                  height: h * .22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA9B796),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1B1E21),
                      width: 3,
                    ),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: CustomPaint(
                      painter: SevenSegmentPainter(
                        value: widget.count,
                        small: widget.rounds,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.ltr,
                  children: [
                    Tooltip(
                      message: l.tasbihLcdHint,
                      child: Semantics(
                        button: true,
                        label: l.tasbihReset,
                        onTap: widget.onReset,
                        onLongPress: widget.onReset,
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: lcdResetKey,
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => setState(() => _rDown = true),
                          onTapCancel: () => setState(() => _rDown = false),
                          onTapUp: (_) => setState(() => _rDown = false),
                          onTap: widget.onReset,
                          onLongPressDown: (_) => setState(() => _rDown = true),
                          onLongPressCancel: () =>
                              setState(() => _rDown = false),
                          onLongPressEnd: (_) => setState(() => _rDown = false),
                          onLongPress: widget.onReset,
                          child: _SmallKey(
                            label: 'R',
                            size: key * .32,
                            pressed: _rDown,
                            animate: widget.animate,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: key * .15),
                    GestureDetector(
                      key: lcdKey,
                      onTapDown: (_) => setState(() => _down = true),
                      onTapCancel: () => setState(() => _down = false),
                      onTapUp: (_) {
                        setState(() => _down = false);
                        widget.onCount();
                      },
                      child: AnimatedContainer(
                        duration: Duration(
                          milliseconds: widget.animate ? 70 : 0,
                        ),
                        width: key,
                        height: key,
                        transform: Matrix4.translationValues(
                          0,
                          _down && widget.animate ? 4 : 0,
                          0,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-.35, -.45),
                            colors: _down
                                ? const [Color(0xFFCDD2D6), Color(0xFF7B8188)]
                                : const [Color(0xFFF4F6F7), Color(0xFF9AA0A6)],
                          ),
                          border: Border.all(
                            color: const Color(0xFF1B1E21),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x66000000),
                              blurRadius: _down ? 2 : 8,
                              offset: Offset(0, _down ? 1 : 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: key * .15 + key * .32),
                  ],
                ),
                SizedBox(height: h * .12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmallKey extends StatelessWidget {
  const _SmallKey({
    required this.label,
    required this.size,
    this.pressed = false,
    this.animate = true,
  });

  final String label;
  final double size;
  final bool pressed;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final s = math.max(size, 44.0);
    final travel = animate ? 3.0 : 0.0;
    return AnimatedContainer(
      duration: Duration(milliseconds: animate ? (pressed ? 50 : 150) : 0),
      curve: pressed ? Curves.easeOut : Curves.easeIn,
      transform: Matrix4.translationValues(0, pressed ? travel : 0, 0),
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pressed ? const Color(0xFF14171A) : const Color(0xFF1B1E21),
        border: Border.all(
          color: pressed ? const Color(0xFF4E545A) : const Color(0xFF6B7178),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: pressed ? 2 : 4,
            offset: Offset(0, pressed ? 1 : 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: pressed ? const Color(0xFFA6ABB0) : const Color(0xFFD5D9DC),
          fontWeight: FontWeight.w700,
          fontSize: math.max(13.0, s * 0.38),
        ),
      ),
    );
  }
}

/// Four seven-segment digits (unlit segments show faintly), and the
/// rounds in two small digits at the corner.
class SevenSegmentPainter extends CustomPainter {
  SevenSegmentPainter({required this.value, required this.small});

  final int value;
  final int small;

  // a b c d e f g, per digit.
  static const _digits = [
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, //
  ];
  static const _on = Color(0xFF1E2619);
  static const _off = Color(0x1A1E2619);

  @override
  void paint(Canvas canvas, Size size) {
    final big = size.height * .9;
    final w = big * .52;
    final gap = w * .22;
    final total = 4 * w + 3 * gap;
    final left = size.width - total - size.width * .02;
    final text = (value % 10000).toString().padLeft(4, ' ');
    for (var i = 0; i < 4; i++) {
      final ch = text[i];
      _digit(
        canvas,
        Rect.fromLTWH(left + i * (w + gap), (size.height - big) / 2, w, big),
        ch == ' ' ? null : int.parse(ch),
      );
    }
    final sh = size.height * .3;
    final sw = sh * .52;
    final r = (small % 100).toString().padLeft(2, ' ');
    for (var i = 0; i < 2; i++) {
      final ch = r[i];
      _digit(
        canvas,
        Rect.fromLTWH(i * (sw + sw * .25), 0, sw, sh),
        ch == ' ' ? null : int.parse(ch),
      );
    }
  }

  void _digit(Canvas canvas, Rect r, int? d) {
    final mask = d == null ? 0 : _digits[d];
    final t = r.width * .17;
    final h2 = r.height / 2;
    final segs = <Rect>[
      Rect.fromLTWH(r.left + t * .6, r.top, r.width - t * 1.2, t),
      Rect.fromLTWH(r.right - t, r.top + t * .6, t, h2 - t * .9),
      Rect.fromLTWH(r.right - t, r.top + h2 + t * .3, t, h2 - t * .9),
      Rect.fromLTWH(r.left + t * .6, r.bottom - t, r.width - t * 1.2, t),
      Rect.fromLTWH(r.left, r.top + h2 + t * .3, t, h2 - t * .9),
      Rect.fromLTWH(r.left, r.top + t * .6, t, h2 - t * .9),
      Rect.fromLTWH(r.left + t * .6, r.top + h2 - t / 2, r.width - t * 1.2, t),
    ];
    for (var i = 0; i < 7; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(segs[i], Radius.circular(t / 2)),
        Paint()..color = mask & (1 << i) != 0 ? _on : _off,
      );
    }
  }

  @override
  bool shouldRepaint(SevenSegmentPainter old) =>
      old.value != value || old.small != small;
}
