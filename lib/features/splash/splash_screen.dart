import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/theme/ornaments.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';

/// The logo's height, the same as the native launch screen's
/// (tools/native_splash.sh), so the hand-over does not jump.
const splashLogoHeight = 112.0;

/// Shown for under a second at launch: the «تبيان» logo where the native
/// launch screen left it, the «هندسي» girih drawing in around it from the
/// centre and a gold light passing along its strokes, from right to left
/// as the pen writes; then the line and tagline. Everything takes the
/// chosen style and light. With reduced motion it is still.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 900),
  });

  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// Where the splash leads: home, or for store screenshots the screen given
/// with `--dart-define=TIBYAN_START=/settings` (tools/store_screenshots.sh).
const _start = String.fromEnvironment('TIBYAN_START', defaultValue: '/');

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration + const Duration(milliseconds: 60), () {
      if (!mounted) return;
      context.go(_start);
      if (ref.read(settingsProvider).onboardingDone) {
        markAppRouterReady(ref.read(appRouterReadyProvider));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.value = 1;
    } else if (!_t.isAnimating && _t.value == 0) {
      _t.forward();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final mark = look.night
        ? look.onFrame
        : (look.isHandasi
              ? look.accent
              : (look.isLayli ? look.ink : look.frame));
    final pattern = (look.isHandasi ? look.accent : look.gold).withValues(
      alpha: look.night ? .16 : .11,
    );
    final shimmer = look.night ? look.gold : look.gold.withValues(alpha: .9);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Animation<double> span(double a, double b) => CurvedAnimation(
      parent: _t,
      curve: Interval(a, b, curve: Curves.easeOutCubic),
    );
    final grow = span(0, .7);
    final sweep = span(.12, .9);
    final words = span(.45, 1);

    return Scaffold(
      backgroundColor: look.bg,
      body: Semantics(
        label: l.appTitle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The girih, drawn in from the centre outward.
            ExcludeSemantics(
              child: AnimatedBuilder(
                animation: grow,
                builder: (context, child) => ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => RadialGradient(
                    radius: .15 + grow.value * 1.1,
                    colors: const [Colors.white, Colors.transparent],
                    stops: const [.55, 1],
                  ).createShader(rect),
                  child: child,
                ),
                child: RepaintBoundary(
                  child: CustomPaint(painter: GirihPainter(pattern, cell: 56)),
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: sweep,
                builder: (context, child) {
                  // A narrow band of gold travelling along the strokes.
                  final at = rtl
                      ? 1.2 - sweep.value * 1.4
                      : sweep.value * 1.4 - .2;
                  final done = sweep.value >= 1;
                  return done
                      ? child!
                      : ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (rect) => LinearGradient(
                            colors: [
                              Colors.transparent,
                              shimmer,
                              Colors.transparent,
                            ],
                            stops: [
                              (at - .12).clamp(0, 1),
                              at.clamp(0, 1),
                              (at + .12).clamp(0, 1),
                            ],
                          ).createShader(rect),
                          child: child,
                        );
                },
                child: TibyanWordmark(color: mark, height: splashLogoHeight),
              ),
            ),
            Align(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: splashLogoHeight + 120,
                  left: 32,
                  right: 32,
                ),
                child: FadeTransition(
                  opacity: words,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 160,
                        child: ExcludeSemantics(child: TazhibBand(height: 10)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.coverTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'KFGQPCAN',
                          fontSize: 18,
                          height: 1.5,
                          color: look.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: look.sub),
                      ),
                    ],
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
