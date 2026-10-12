import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';

/// Shown briefly at launch: the brand on the interface style's ground (its
/// dark frame at night) with the style's pattern.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// Where the splash leads: home, or for store screenshots the screen given
/// with `--dart-define=TIBYAN_START=/settings` (tools/store_screenshots.sh).
const _start = String.fromEnvironment('TIBYAN_START', defaultValue: '/');

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      context.go(_start);
      if (ref.read(settingsProvider).onboardingDone) {
        markAppRouterReady(ref.read(appRouterReadyProvider));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    // Night: the style's dark frame; day: its ground.
    final ground = look.night ? look.frame : look.bg;
    final mark = look.night
        ? look.onFrame
        : (look.isHandasi
              ? look.accent
              : (look.isLayli ? look.ink : look.frame));
    final line = look.night ? look.onFrame : look.sub;
    return Scaffold(
      backgroundColor: ground,
      body: Semantics(
        label: l.appTitle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const LookBackground(hero: true),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TibyanLogo(color: mark, height: 112),
                      const SizedBox(height: 24),
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
                          color: line,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: line),
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
