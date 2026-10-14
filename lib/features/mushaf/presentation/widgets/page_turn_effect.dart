import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/settings/app_settings.dart';

/// Draws one item of the mushaf's pager with the chosen «تأثير قلب الصفحة».
///
/// The pager still lays the pages side by side and scrolls them, so a drag
/// follows the finger and a fling settles with the pager's own timing; this
/// only paints. The item's slide is cancelled so both pages of a turn share
/// the screen, then:
/// * [PageTurn.curl]: the earlier page is a leaf of paper hinged at its
///   spine. Turning on (finger from left to right in the Arabic mushaf), its
///   free edge lifts and swings toward the spine in perspective, uncovering
///   the next page; turning back, it swings down over the page again. The
///   later page is drawn only where the leaf has uncovered it.
/// * [PageTurn.fade]: the later page fades in over the earlier one.
///
/// At rest every page is drawn untouched, so taps and selection are
/// unaffected. While it turns, the leaf is a snapshot of the page taken as
/// the turn starts: each frame moves one image, it does not draw the page
/// again in perspective.
class PageTurnEffect extends StatefulWidget {
  const PageTurnEffect({
    super.key,
    required this.controller,
    required this.index,
    required this.effect,
    required this.child,
    this.isSpread,
  });

  final PageController? controller;
  final int index;
  final PageTurn effect;
  final Widget child;

  /// Whether the pager's item at an index is two facing pages (a spread).
  /// When both items of a turn are, the turn is a single leaf: the left
  /// page lifts at the spine and lays itself over the right one, as in a
  /// printed mushaf, instead of the whole screen turning as one page.
  final bool Function(int index)? isSpread;

  /// A spread's leaf turned by [angle] about the spine (the middle).
  /// [flat]: no perspective, the leaf only narrows to the spine and widens.
  static Matrix4 spreadLeafTransform(
    double angle,
    Size size, {
    bool flat = false,
  }) {
    final hinge = Offset(size.width / 2, size.height / 2);
    // Kept proportional to the half's width so the far edge never passes
    // behind the eye on a very wide screen.
    final persp = flat ? 0.0 : 0.45 / math.max(1, size.width / 2);
    return Matrix4.translationValues(hinge.dx, hinge.dy, 0)
      ..multiply(
        Matrix4.identity()
          ..setEntry(3, 2, persp)
          ..rotateY(angle),
      )
      ..multiply(Matrix4.translationValues(-hinge.dx, -hinge.dy, 0));
  }

  /// The perspective's strength: Matrix4 entry (3, 2).
  static const depth = 0.0008;

  /// The leaf's transform about its hinge (the spine), [d] (−1..0) into
  /// the turn: its free edge lifts off the page toward the reader.
  static Matrix4 leafTransform(double d, Size size, bool rtl) {
    final side = rtl ? -1.0 : 1.0;
    final hinge = Offset(rtl ? size.width : 0, size.height / 2);
    return Matrix4.translationValues(hinge.dx, hinge.dy, 0)
      ..multiply(
        Matrix4.identity()
          ..setEntry(3, 2, depth)
          ..rotateY(-d * math.pi / 2 * side),
      )
      ..multiply(Matrix4.translationValues(-hinge.dx, -hinge.dy, 0));
  }

  @override
  State<PageTurnEffect> createState() => _PageTurnEffectState();
}

class _PageTurnEffectState extends State<PageTurnEffect> {
  final _boundary = GlobalKey();
  ui.Image? _snapshot;

  /// The pager's items by index, so the turning page can draw the page
  /// beneath it from that page's snapshot.
  static final _items = Expando<Map<int, _PageTurnEffectState>>();

  /// «انحناء الورقة»'s shader, loaded once; null until it is (or where
  /// shaders are not supported, where the light curl is drawn instead).
  static ui.FragmentProgram? _program;
  static bool _loading = false;

  static void _loadProgram() {
    if (_program != null || _loading) return;
    _loading = true;
    ui.FragmentProgram.fromAsset('shaders/page_curl.frag')
        .then((p) => _program = p, onError: (_) {});
    ui.FragmentProgram.fromAsset('shaders/page_curl_spread.frag')
        .then((p) => _spreadProgram = p, onError: (_) {});
  }

  /// «انحناء الورقة» across two facing pages.
  static ui.FragmentProgram? _spreadProgram;

  Map<int, _PageTurnEffectState>? get _siblings {
    final c = widget.controller;
    return c == null ? null : (_items[c] ??= {});
  }

  @override
  void dispose() {
    final siblings = _siblings;
    if (siblings?[widget.index] == this) siblings!.remove(widget.index);
    _drop();
    super.dispose();
  }

  void _drop() {
    _snapshot?.dispose();
    _snapshot = null;
    _halves[0]?.dispose();
    _halves[1]?.dispose();
    _halves[0] = _halves[1] = null;
  }

  /// The snapshot's left [0] and right [1] pages, cut once per turn for
  /// «انحناء الورقة» on a spread.
  final _halves = List<ui.Image?>.filled(2, null);

  ui.Image? _half(bool left) {
    final shot = _snapshot;
    if (shot == null) return null;
    final i = left ? 0 : 1;
    final have = _halves[i];
    if (have != null) return have;
    final w = shot.width ~/ 2;
    final h = shot.height;
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
      shot,
      Rect.fromLTWH(
        left ? 0 : (shot.width - w).toDouble(),
        0,
        w + 0.0,
        h + 0.0,
      ),
      Rect.fromLTWH(0, 0, w + 0.0, h + 0.0),
      Paint()..filterQuality = FilterQuality.none,
    );
    final pic = rec.endRecording();
    try {
      return _halves[i] = pic.toImageSync(w, h);
    } catch (_) {
      return null;
    } finally {
      pic.dispose();
    }
  }

  int _prepared = 0;

  void _prepare() {
    final ticket = ++_prepared;
    SchedulerBinding.instance.scheduleTask(() {
      if (!mounted || ticket != _prepared || _snapshot != null) return;
      final c = widget.controller;
      if (c == null || !c.hasClients || c.position.isScrollingNotifier.value) {
        return;
      }
      _snap();
    }, Priority.idle);
  }

  /// The page as it was last painted, or null when it was not (off screen).
  ui.Image? _snap() {
    if (_snapshot != null) return _snapshot;
    try {
      // The boundary may be moving in the tree as the turn starts (its
      // element inactive for the moment): no snapshot this frame then.
      final box = _boundary.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary || !box.hasSize) {
        return null;
      }
      return _snapshot = box.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null ||
        // The normal slide is untouched, except between two spreads,
        // where one page turns flat over the spine.
        (widget.effect == PageTurn.normal &&
            widget.isSpread?.call(widget.index) != true) ||
        MediaQuery.disableAnimationsOf(context)) {
      _drop();
      return widget.child;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _siblings![widget.index] = this;
    if (widget.effect == PageTurn.bend) _loadProgram();
    final page = RepaintBoundary(key: _boundary, child: widget.child);
    return AnimatedBuilder(
      animation: controller,
      child: page,
      builder: (context, page) {
        final d = _offset(controller);
        if (d == -1 ||
            (d == 1 &&
                (widget.effect == PageTurn.bend ||
                    _spreadPair(1) ||
                    _spreadPair(-1)))) {
          // The page before, built beside the screen: turning back it is
          // the leaf, so it is ready too. The page after is what the
          // curl uncovers.
          if (_snapshot == null) _prepare();
          return page!;
        }
        if (d.abs() >= 1) {
          _drop();
          return page!;
        }
        if (d == 0) {
          // At rest on screen: the page is next to turn, so its snapshot
          // is taken now, when the app is idle, not in the turn's first
          // frame. A page that changes (a selection, a highlight) is
          // taken again.
          _drop();
          _prepare();
          return page!;
        }
        return LayoutBuilder(
          builder: (context, box) => _paint(d, box.biggest, rtl, page!),
        );
      },
    );
  }

  /// Where this item is in the turn: 0 at rest on screen, +1 a whole page
  /// on (the next page), −1 a whole page back.
  double _offset(PageController controller) {
    if (!controller.hasClients) return 0;
    final p = controller.position;
    if (!p.hasContentDimensions || !p.hasPixels) return 0;
    final at = controller.page;
    if (at == null) return 0;
    return widget.index - at;
  }

  /// «انحناء الورقة»: the shader draws the curling page and, where it has
  /// rolled away, the page beneath; that page is drawn too, beyond the
  /// curl, so nothing is missing before its snapshot is ready. Null when
  /// the shader or the snapshot is not there: the light curl stands in.
  Widget? _curl(double d, Size size, bool rtl, Matrix4 undo, Widget page) {
    final program = _program;
    if (program == null) return null;
    final t = d > 0 ? 1 - d : -d;
    final curl = CurlGeometry(t, size, rtl);
    if (d > 0) {
      return Transform(
        transform: undo,
        child: ClipPath(clipper: _Beyond(curl), child: page),
      );
    }
    final shot = _snap();
    if (shot == null) return null;
    final next = _siblings?[widget.index + 1]?._snapshot;
    return Transform(
      transform: undo,
      child: IgnorePointer(
        child: CustomPaint(
          size: size,
          painter: _CurlPainter(program, curl, shot, next),
        ),
      ),
    );
  }

  /// Whether this item and the one it turns with, on the side [d] says
  /// (the next item when d < 0, the one before when d > 0), are spreads.
  bool _spreadPair(double d) {
    final f = widget.isSpread;
    if (f == null || d == 0) return false;
    return f(widget.index) && f(widget.index + (d < 0 ? 1 : -1));
  }

  /// A turn between two spreads (the mushaf is right to left: the later
  /// spread lies to the left). One leaf turns over the spine:
  /// * the first half: the earlier spread's left page lifts, its free edge
  ///   rising toward the reader, and uncovers the later spread's left page;
  /// * the second half: the leaf's back, the later spread's right page,
  ///   comes down over the earlier spread's right page.
  /// Turning back plays the same in reverse. Each item draws only its own
  /// pages, clipped where the leaf is, so the pager's paint order does not
  /// matter.
  Widget _spreadTurn(
    double d,
    Size size,
    Matrix4 undo,
    Widget page, {
    bool flat = false,
  }) {
    final later = d > 0;
    // 0 at the earlier spread, 1 at the later one.
    final t = later ? 1 - d : -d;
    final half = size.width / 2;
    final left = Rect.fromLTWH(0, 0, half, size.height);
    final right = Rect.fromLTWH(half, 0, half, size.height);
    final lifting = t < 0.5;
    final angle = lifting ? -t * math.pi : (1 - t) * math.pi;
    final leafRect = lifting ? left : right;
    final leaf = PageTurnEffect.spreadLeafTransform(angle, size, flat: flat);
    final ownsLeaf = later != lifting;
    // The still part of this item: the later spread's left page, the
    // earlier's right, minus wherever the leaf is over it.
    final still = later ? left : right;
    // «عادي» turns flat: no light, no shadow.
    final lift = flat ? 0.0 : math.sin(t * math.pi);
    final shot = ownsLeaf ? _snap() : null;
    return Transform(
      transform: undo,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            ClipPath(
              clipper: _SpreadStill(still, leaf, leafRect),
              child: CustomPaint(
                foregroundPainter: _SpreadShade(still, lift, half),
                child: page,
              ),
            ),
            if (ownsLeaf)
              Transform(
                transform: leaf,
                child: ClipRect(
                  clipper: _RectClip(leafRect),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      // The page itself is already in the tree (the still
                      // part): until its snapshot is there, plain paper.
                      if (shot == null)
                        const ColoredBox(color: Color(0xFFF7F3EA))
                      else
                        RawImage(
                          image: shot,
                          width: size.width,
                          height: size.height,
                          fit: BoxFit.fill,
                        ),
                      Positioned.fromRect(
                        rect: leafRect,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              // Dark in the bend at the spine, lit at the
                              // free edge as it rises toward the light.
                              begin: lifting
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              end: lifting
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              colors: [
                                Color.fromRGBO(0, 0, 0, 0.25 * lift),
                                const Color(0x00000000),
                                Color.fromRGBO(255, 255, 255, 0.15 * lift),
                              ],
                              stops: const [0, 0.4, 1],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// «تلاشي» between spreads: the later spread's left page fades in over
  /// the first half of the turn, then its right page. The pager paints its
  /// items in order, so the later spread is drawn over the earlier.
  Widget _spreadFade(double d, Matrix4 undo, Widget page) {
    if (d < 0) return Transform(transform: undo, child: page);
    final t = 1 - d;
    final a = (2 * t).clamp(0.0, 1.0);
    final b = (2 * t - 1).clamp(0.0, 1.0);
    return Transform(
      transform: undo,
      child: IgnorePointer(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [
              Color.fromRGBO(0, 0, 0, a),
              Color.fromRGBO(0, 0, 0, a),
              Color.fromRGBO(0, 0, 0, b),
              Color.fromRGBO(0, 0, 0, b),
            ],
            stops: const [0, 0.5, 0.5, 1],
          ).createShader(rect),
          child: page,
        ),
      ),
    );
  }

  /// «طي الصفحة» between spreads: the earlier spread's left page folds
  /// from its lower free corner and is laid over the right page, the fold
  /// reaching the spine as the turn ends. The flap shows the leaf's back:
  /// the later spread's right page, where it will lie.
  Widget _spreadFold(double d, Size size, Matrix4 undo, Widget page) {
    final later = d > 0;
    final t = later ? 1 - d : -d;
    final half = size.width / 2;
    final fold = Fold(t, Size(half, size.height), true);
    if (!later) {
      return Transform(
        transform: undo,
        child: IgnorePointer(
          child: ClipPath(
            clipper: _PathClip(
              (s) => Path.combine(
                PathOperation.difference,
                Path()..addRect(Offset.zero & s),
                Path.combine(PathOperation.union, fold.lifted, fold.flap),
              ),
              t,
            ),
            child: page,
          ),
        ),
      );
    }
    return Transform(
      transform: undo,
      child: IgnorePointer(
        child: CustomPaint(
          foregroundPainter: _SpreadFlapPainter(fold, _snap(), half),
          child: ClipPath(
            clipper: _PathClip((_) => fold.lifted, t),
            child: CustomPaint(
              foregroundPainter: _FoldShadow(fold),
              child: page,
            ),
          ),
        ),
      ),
    );
  }

  /// «انحناء الورقة» between spreads: the earlier spread's left page rolls
  /// from its free edge toward the spine, and the rolled part lies over
  /// the spine and down onto the right page, its back showing the later
  /// spread's right page; under it, the later spread's left page. One
  /// shader draws the whole spread, from the later item (painted over the
  /// earlier); the earlier is hidden meanwhile. Null until the shader and
  /// both spreads' snapshots are ready.
  Widget? _spreadBend(double d, Size size, Matrix4 undo, Widget page) {
    final program = _spreadProgram;
    if (program == null) return null;
    final later = d > 0;
    final t = later ? 1 - d : -d;
    final other = _siblings?[widget.index + (later ? -1 : 1)];
    if (other == null || _snap() == null || other._snap() == null) {
      return null;
    }
    final earlier = later ? other : this;
    final latter = later ? this : other;
    final front = earlier._half(true);
    final right = earlier._half(false);
    final under = latter._half(true);
    final back = latter._half(false);
    if (front == null || right == null || under == null || back == null) {
      return null;
    }
    final hidden = ClipRect(clipper: const _RectClip(Rect.zero), child: page);
    if (!later) return Transform(transform: undo, child: hidden);
    return Transform(
      transform: undo,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            hidden,
            CustomPaint(
              size: size,
              painter: _SpreadCurlPainter(
                program,
                SpreadCurl(t, size),
                front,
                back,
                under,
                right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paint(double d, Size size, bool rtl, Widget page) {
    // In a right-to-left pager the later pages lie to the left.
    final side = rtl ? -1.0 : 1.0;
    // Undo the slide: both pages of the turn sit on the screen.
    final undo = Matrix4.translationValues(-d * size.width * side, 0, 0);
    if (_spreadPair(d)) {
      return switch (widget.effect) {
        PageTurn.normal => _spreadTurn(d, size, undo, page, flat: true),
        PageTurn.curl => _spreadTurn(d, size, undo, page),
        PageTurn.fade => _spreadFade(d, undo, page),
        PageTurn.fold => _spreadFold(d, size, undo, page),
        PageTurn.bend =>
          _spreadBend(d, size, undo, page) ?? _spreadTurn(d, size, undo, page),
      };
    }
    // Between a single page and a spread (the opening pages).
    if (widget.effect == PageTurn.normal) return page;
    if (widget.effect == PageTurn.fade) {
      return Transform(
        transform: undo,
        child: d > 0 ? Opacity(opacity: 1 - d, child: page) : page,
      );
    }
    if (widget.effect == PageTurn.bend) {
      final curled = _curl(d, size, rtl, undo, page);
      if (curled != null) return curled;
    }
    if (widget.effect == PageTurn.bend || widget.effect == PageTurn.fold) {
      if (d > 0) {
        // The later page, where the fold has uncovered it.
        final fold = Fold(1 - d, size, rtl);
        return Transform(
          transform: undo,
          child: ClipPath(
            clipper: _FoldClip(fold, uncovered: true),
            child: CustomPaint(
              foregroundPainter: _FoldShadow(fold),
              child: page,
            ),
          ),
        );
      }
      final fold = Fold(-d, size, rtl);
      return Transform(
        transform: undo,
        child: CustomPaint(
          foregroundPainter: _FlapPainter(
            fold,
            _snap(),
            MediaQuery.devicePixelRatioOf(context),
          ),
          child: ClipPath(
            clipper: _FoldClip(fold, uncovered: false),
            child: page,
          ),
        ),
      );
    }
    if (d > 0) {
      // The later page: seen only where the leaf has uncovered it, with
      // the lifted leaf's shadow along its edge.
      return Transform(
        transform: undo,
        child: ClipPath(
          clipper: _Uncovered(d - 1, rtl),
          child: CustomPaint(
            foregroundPainter: _LeafShadow(d - 1, rtl),
            child: page,
          ),
        ),
      );
    }
    // The leaf: shaded at the spine where it bends, lit at the free edge
    // as it rises toward the light.
    final shot = _snap();
    final lift = math.sin(-d * math.pi / 2);
    return Transform(
      transform: undo,
      child: Transform(
        transform: PageTurnEffect.leafTransform(d, size, rtl),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (shot == null)
              page
            else
              IgnorePointer(
                child: RawImage(
                  image: shot,
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.fill,
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                      end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.22 * lift),
                        const Color(0x00000000),
                        Color.fromRGBO(255, 255, 255, 0.18 * lift),
                      ],
                      stops: const [0, 0.35, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page minus the leaf turned [d] (−1..0) over it.
class _Uncovered extends CustomClipper<Path> {
  const _Uncovered(this.d, this.rtl);

  final double d;
  final bool rtl;

  @override
  Path getClip(Size size) {
    final m = PageTurnEffect.leafTransform(d, size, rtl);
    Offset at(double x, double y) =>
        MatrixUtils.transformPoint(m, Offset(x, y));
    final leaf = Path()
      ..addPolygon([
        at(0, 0),
        at(size.width, 0),
        at(size.width, size.height),
        at(0, size.height),
      ], true);
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      leaf,
    );
  }

  @override
  bool shouldReclip(_Uncovered old) => old.d != d || old.rtl != rtl;
}

/// The shadow the lifted leaf, turned [d] (−1..0), casts on the page under
/// it: darkest at the leaf's free edge, fading away from it.
class _LeafShadow extends CustomPainter {
  const _LeafShadow(this.d, this.rtl);

  final double d;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final lift = math.sin(-d * math.pi / 2);
    if (lift <= 0) return;
    final m = PageTurnEffect.leafTransform(d, size, rtl);
    final edge = MatrixUtils.transformPoint(
      m,
      Offset(rtl ? 0 : size.width, size.height / 2),
    ).dx;
    // The higher the leaf, the longer and softer its shadow.
    final reach = 24 + 56 * lift;
    final away = rtl ? -reach : reach;
    final rect = Rect.fromLTRB(
      math.min(edge, edge + away),
      0,
      math.max(edge, edge + away),
      size.height,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Color.fromRGBO(0, 0, 0, 0.30 * (1 - lift * 0.4)),
            const Color(0x00000000),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LeafShadow old) => old.d != d || old.rtl != rtl;
}

/// «انحناء الورقة»: where the turning page is folded, [t] (0..1) into the
/// turn. The page's free edge (the left in the Arabic mushaf) is carried
/// over toward the spine; the fold runs between [top] and [bottom], slanted
/// mid-turn as a page held by its lower corner is, and upright at either
/// end.
class Fold {
  Fold(this.t, this.size, this.rtl) {
    final w = size.width;
    final xb = t * w;
    final xt = math.min(w, xb + 1.2 * w * t * (1 - t));
    // Laid out for a free edge on the left, then mirrored for the other.
    top = Offset(rtl ? xt : w - xt, 0);
    bottom = Offset(rtl ? xb : w - xb, size.height);
  }

  final double t;
  final Size size;
  final bool rtl;
  late final Offset top;
  late final Offset bottom;

  /// The part of the page the fold has lifted: between the free edge and
  /// the fold.
  Path get lifted {
    final edge = rtl ? 0.0 : size.width;
    return Path()..addPolygon([
      Offset(edge, 0),
      top,
      bottom,
      Offset(edge, size.height),
    ], true);
  }

  /// Mirrors a point of the page across the fold.
  Matrix4 get reflection {
    final u = bottom - top;
    final n = u / u.distance;
    final a = n.dx * n.dx - n.dy * n.dy;
    final b = 2 * n.dx * n.dy;
    final m = Matrix4.identity()
      ..setEntry(0, 0, a)
      ..setEntry(0, 1, b)
      ..setEntry(1, 0, b)
      ..setEntry(1, 1, -a);
    return Matrix4.translationValues(top.dx, top.dy, 0)
      ..multiply(m)
      ..multiply(Matrix4.translationValues(-top.dx, -top.dy, 0));
  }

  /// The flap: the lifted part, laid back over the page across the fold.
  Path get flap => lifted.transform(reflection.storage);

  /// A unit vector across the fold, pointing from it over the flap.
  Offset get across {
    final u = bottom - top;
    final n = Offset(-u.dy, u.dx) / u.distance;
    return (rtl ? n.dx > 0 : n.dx < 0) ? n : -n;
  }
}

class _FoldClip extends CustomClipper<Path> {
  const _FoldClip(this.fold, {required this.uncovered});

  final Fold fold;
  final bool uncovered;

  @override
  Path getClip(Size size) => uncovered
      ? fold.lifted
      : Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          fold.lifted,
        );

  @override
  bool shouldReclip(_FoldClip old) =>
      old.fold.t != fold.t || old.uncovered != uncovered;
}

/// The lifted flap: the page's back, its print showing faintly through
/// the paper, shaded where it bends at the fold and lit at its edge, with
/// its shadow on the page under it.
class _FlapPainter extends CustomPainter {
  const _FlapPainter(this.fold, this.image, this.ratio);

  final Fold fold;
  final ui.Image? image;
  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    if (fold.t <= 0) return;
    final flap = fold.flap;
    final across = fold.across;
    final reach = fold.t * size.width;
    final from = fold.top + (fold.bottom - fold.top) / 2;
    // Its shadow on the page, beyond the flap's edge.
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        flap,
      ),
    );
    final shadow = flap.shift(across * 10);
    canvas.drawPath(
      shadow,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();
    // The back of the paper.
    canvas.save();
    canvas.clipPath(flap);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F3EA),
    );
    final shot = image;
    if (shot != null) {
      canvas.save();
      canvas.transform(fold.reflection.storage);
      canvas.drawImageRect(
        shot,
        Offset.zero & Size(shot.width.toDouble(), shot.height.toDouble()),
        Offset.zero & size,
        Paint()
          ..color = const Color(0x24000000)
          ..filterQuality = FilterQuality.low,
      );
      canvas.restore();
    }
    // Dark in the bend at the fold, lighter toward the flap's edge.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          from,
          from + across * math.max(1, reach),
          const [Color(0x33000000), Color(0x00000000), Color(0x22FFFFFF)],
          const [0, 0.45, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlapPainter old) =>
      old.fold.t != fold.t || old.image != image;
}

/// The shade on the page beneath, deepest at the fold where the paper
/// lifts off it.
class _FoldShadow extends CustomPainter {
  const _FoldShadow(this.fold);

  final Fold fold;

  @override
  void paint(Canvas canvas, Size size) {
    if (fold.t <= 0) return;
    final from = fold.top + (fold.bottom - fold.top) / 2;
    final reach = 30 + 40 * math.sin(fold.t * math.pi);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(from, from - fold.across * reach, const [
          Color(0x55000000),
          Color(0x00000000),
        ]),
    );
  }

  @override
  bool shouldRepaint(_FoldShadow old) => old.fold.t != fold.t;
}

/// The cylinder of «انحناء الورقة», [t] (0..1) into the turn: its axis
/// sweeps from the free edge (the left in the Arabic mushaf) past the
/// spine, slanted mid-turn as a page held by its lower corner is.
class CurlGeometry {
  CurlGeometry(this.t, this.size, this.rtl) {
    final tilt = 0.3 * (1 - t);
    final n = Offset(rtl ? -1 : 1, tilt);
    normal = n / n.distance;
    radius = size.width * 0.12;
    final dots = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => c.dx * normal.dx + c.dy * normal.dy);
    final hi = dots.reduce(math.max);
    final lo = dots.reduce(math.min);
    axis = hi + (lo - radius - hi) * t;
  }

  final double t;
  final Size size;
  final bool rtl;
  late final Offset normal;
  late final double radius;
  late final double axis;

  /// Where the curl has rolled away from: beyond the cylinder.
  Path beyond() {
    // The line dot(p, normal) = axis + radius, as a big half-plane.
    final at = axis + radius;
    final o = normal * at;
    final along = Offset(-normal.dy, normal.dx) * 1e4;
    final out = normal * 1e4;
    return Path()..addPolygon([
      o - along,
      o + along,
      o + along + out,
      o - along + out,
    ], true);
  }
}

class _Beyond extends CustomClipper<Path> {
  const _Beyond(this.curl);

  final CurlGeometry curl;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.intersect,
    Path()..addRect(Offset.zero & size),
    curl.beyond(),
  );

  @override
  bool shouldReclip(_Beyond old) => old.curl.t != curl.t;
}

class _CurlPainter extends CustomPainter {
  const _CurlPainter(this.program, this.curl, this.page, this.next);

  final ui.FragmentProgram program;
  final CurlGeometry curl;
  final ui.Image page;
  final ui.Image? next;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, curl.normal.dx)
      ..setFloat(3, curl.normal.dy)
      ..setFloat(4, curl.axis)
      ..setFloat(5, curl.radius)
      ..setFloat(6, next == null ? 0 : 1)
      ..setImageSampler(0, page)
      ..setImageSampler(1, next ?? page);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_CurlPainter old) =>
      old.curl.t != curl.t || old.page != page || old.next != next;
}

class _RectClip extends CustomClipper<Rect> {
  const _RectClip(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClip old) => old.rect != rect;
}

/// A spread's still half, [still], minus the leaf ([leafRect] turned by
/// [leaf]) where it lies over it.
class _SpreadStill extends CustomClipper<Path> {
  const _SpreadStill(this.still, this.leaf, this.leafRect);

  final Rect still;
  final Matrix4 leaf;
  final Rect leafRect;

  @override
  Path getClip(Size size) {
    Offset at(Offset p) => MatrixUtils.transformPoint(leaf, p);
    final over = Path()
      ..addPolygon([
        at(leafRect.topLeft),
        at(leafRect.topRight),
        at(leafRect.bottomRight),
        at(leafRect.bottomLeft),
      ], true);
    return Path.combine(PathOperation.difference, Path()..addRect(still), over);
  }

  @override
  bool shouldReclip(_SpreadStill old) =>
      old.still != still || old.leaf != leaf || old.leafRect != leafRect;
}

/// The shade the lifted leaf casts on the still half, deepest at the spine.
class _SpreadShade extends CustomPainter {
  const _SpreadShade(this.still, this.lift, this.spine);

  final Rect still;
  final double lift;
  final double spine;

  @override
  void paint(Canvas canvas, Size size) {
    if (lift <= 0) return;
    final reach = still.width * (0.15 + 0.25 * lift);
    final toward = still.center.dx < spine ? -reach : reach;
    canvas.drawRect(
      still,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(spine, 0),
          Offset(spine + toward, 0),
          [Color.fromRGBO(0, 0, 0, 0.28 * lift), const Color(0x00000000)],
        ),
    );
  }

  @override
  bool shouldRepaint(_SpreadShade old) =>
      old.lift != lift || old.still != still || old.spine != spine;
}

class _PathClip extends CustomClipper<Path> {
  const _PathClip(this.path, this.t);

  final Path Function(Size size) path;

  /// The turn's progress: the clip changes only with it.
  final double t;

  @override
  Path getClip(Size size) => path(size);

  @override
  bool shouldReclip(_PathClip old) => old.t != t;
}

/// «طي الصفحة» on a spread: the flap, laid over the right page, shows the
/// later spread's right page where it will lie once the fold reaches the
/// spine, shaded where it bends at the fold, with its shadow beyond it.
class _SpreadFlapPainter extends CustomPainter {
  const _SpreadFlapPainter(this.fold, this.image, this.spine);

  final Fold fold;
  final ui.Image? image;
  final double spine;

  @override
  void paint(Canvas canvas, Size size) {
    if (fold.t <= 0) return;
    final flap = fold.flap;
    final across = fold.across;
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path.combine(PathOperation.union, flap, fold.lifted),
      ),
    );
    canvas.drawPath(
      flap.shift(across * 10),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();
    canvas.save();
    canvas.clipPath(flap);
    final shot = image;
    if (shot == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFF7F3EA),
      );
    } else {
      // A point of the flap is a point of the leaf (across the fold),
      // which lands mirrored across the spine.
      final mirror = Matrix4.translationValues(2 * spine, 0, 0)
        ..multiply(Matrix4.diagonal3Values(-1, 1, 1));
      canvas.transform((fold.reflection..multiply(mirror)).storage);
      canvas.drawImageRect(
        shot,
        Offset.zero & Size(shot.width.toDouble(), shot.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
    canvas.save();
    canvas.clipPath(flap);
    final from = fold.top + (fold.bottom - fold.top) / 2;
    final reach = math.max(1.0, fold.t * spine);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          from,
          from + across * reach,
          const [Color(0x40000000), Color(0x00000000), Color(0x1AFFFFFF)],
          const [0, 0.45, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpreadFlapPainter old) =>
      old.fold.t != fold.t || old.image != image || old.spine != spine;
}

/// «انحناء الورقة» on a spread, [t] (0..1) into the turn: the cylinder's
/// axis sweeps the left page from its free edge to the spine, slanted
/// mid-turn as a page held by its lower corner is, and narrows to nothing
/// as the leaf comes to lie flat on the right page.
class SpreadCurl {
  SpreadCurl(this.t, this.size) {
    final half = size.width / 2;
    final tilt = 0.3 * (1 - t);
    final n = Offset(-1, tilt);
    normal = n / n.distance;
    radius = half * 0.16 * math.pow(1 - t, 0.7);
    double dot(Offset c) => c.dx * normal.dx + c.dy * normal.dy;
    final hi = [
      Offset.zero,
      Offset(half, 0),
      Offset(0, size.height),
      Offset(half, size.height),
    ].map(dot).reduce(math.max);
    final end = dot(Offset(half, size.height / 2));
    axis = hi + (end - hi) * t;
  }

  final double t;
  final Size size;
  late final Offset normal;
  late final double radius;
  late final double axis;
}

class _SpreadCurlPainter extends CustomPainter {
  const _SpreadCurlPainter(
    this.program,
    this.curl,
    this.front,
    this.back,
    this.under,
    this.right,
  );

  final ui.FragmentProgram program;
  final SpreadCurl curl;
  final ui.Image front;
  final ui.Image back;
  final ui.Image under;
  final ui.Image right;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, curl.normal.dx)
      ..setFloat(3, curl.normal.dy)
      ..setFloat(4, curl.axis)
      ..setFloat(5, curl.radius)
      ..setImageSampler(0, front)
      ..setImageSampler(1, back)
      ..setImageSampler(2, under)
      ..setImageSampler(3, right);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_SpreadCurlPainter old) =>
      old.curl.t != curl.t ||
      old.front != front ||
      old.back != back ||
      old.under != under ||
      old.right != right;
}
