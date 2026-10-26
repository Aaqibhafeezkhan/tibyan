import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart' show digitsFamily;
import '../../../core/theme/interface_style.dart';
import '../../../core/ui/look_kit.dart';
import '../../../core/ui/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../../settings/settings_catalog.dart' show SettingsSection;
import '../domain/dhikr.dart';
import '../domain/tasbih_counter.dart';
import '../platform/tasbih_platform.dart';
import '../tasbih_providers.dart';
import '../tasbih_settings.dart';
import 'dhikr_sheet.dart';
import 'styles/counter_styles.dart';
import 'styles/misbaha_view.dart';

const tasbihLocation = '/tasbih';

/// The misbaha's emblem: beads.
const tasbihIcon = Icons.scatter_plot_outlined;

/// «المسبحة»: the dhikr at the top, the count, the round's target, and
/// the counter in the style chosen in its settings.
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _keys;
  StreamSubscription<void>? _watch;
  late final TasbihPlatform _platform = ref.read(tasbihPlatformProvider);
  final _focus = FocusNode(debugLabel: 'tasbih');

  /// The ring stays full for a moment when a round closes.
  bool _closing = false;
  Timer? _closingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keys = _platform.volumeKey.listen((_) => _count(announce: true));
    // Counts made on the watch join the count while this screen is open.
    _watch = _platform.pendingAdded.listen((_) => unawaited(_absorb()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_absorb());
      _applyPlatform(ref.read(tasbihSettingsProvider));
      unawaited(ref.read(tasbihRepositoryProvider).prune());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_keys?.cancel());
    unawaited(_watch?.cancel());
    _closingTimer?.cancel();
    _focus.dispose();
    unawaited(_platform.setVolumeKeys(false));
    unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_absorb());
  }

  Future<void> _absorb() async {
    await ref.read(tasbihCounterProvider.notifier).absorbPending();
    await ref.read(tasbihCounterProvider.notifier).syncWidget();
  }

  void _applyPlatform(TasbihSettings s) {
    final platform = ref.read(tasbihPlatformProvider);
    unawaited(platform.setVolumeKeys(s.volumeKeys));
    unawaited(
      (s.keepScreenOn ? WakelockPlus.enable() : WakelockPlus.disable())
          .catchError((_) {}),
    );
  }

  Future<void> _count({bool announce = false}) async {
    final event = await ref.read(tasbihCounterProvider.notifier).tap();
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final c = ref.read(tasbihCounterProvider);
    if (event == CountEvent.roundClosed) {
      setState(() => _closing = true);
      _closingTimer?.cancel();
      _closingTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _closing = false);
      });
    }
    final stage = c.stage;
    final message = switch (event) {
      CountEvent.roundClosed => l.tasbihRoundClosed(digits(c.rounds)),
      CountEvent.stageChanged when stage != null => l.tasbihStageAnnounce(
        digits(stage.index + 1),
        digits(c.stages!.length),
      ),
      _ => announce ? digits(c.count) : null,
    };
    if (message != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          message,
          Directionality.of(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tasbihSettingsProvider, (prev, next) {
      if (prev?.volumeKeys != next.volumeKeys ||
          prev?.keepScreenOn != next.keepScreenOn) {
        _applyPlatform(next);
      }
    });
    final s = ref.watch(tasbihSettingsProvider);
    final l = AppLocalizations.of(context);
    final style = s.style;
    final keys = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _count,
        const SingleActivator(LogicalKeyboardKey.enter): _count,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _count,
        const SingleActivator(LogicalKeyboardKey.keyR): ref
            .read(tasbihCounterProvider.notifier)
            .reset,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: style == TasbihStyle.screen
            ? _WholeScreen(onCount: _count, closing: _closing)
            : _Layout(onCount: _count, closing: _closing),
      ),
    );
    return LookScaffold(
      maxWidth: double.infinity,
      rail: style != TasbihStyle.screen,
      body: SafeArea(
        child: style == TasbihStyle.screen
            ? keys
            : Column(
                children: [
                  LookTopBar(
                    title: l.tasbihTitle,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.event_note_outlined),
                        tooltip: l.tasbihLog,
                        onPressed: () => context.push('$tasbihLocation/log'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: l.settingsSectionTasbih,
                        onPressed: () =>
                            context.push(SettingsSection.tasbih.location),
                      ),
                    ],
                  ),
                  Expanded(child: keys),
                ],
              ),
      ),
    );
  }
}

/// The screen in the misbaha, button and electronic styles: one column on
/// a phone; on a wide window the dhikr and the target beside the counter.
class _Layout extends ConsumerWidget {
  const _Layout({required this.onCount, required this.closing});

  final VoidCallback onCount;
  final bool closing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(tasbihSettingsProvider);
    final c = ref.watch(tasbihCounterProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final elderly = context.look.elderly;
    final progress = closing ? 1.0 : c.progress;
    final Widget counter = switch (s.style) {
      TasbihStyle.misbaha => MisbahaView(
        material: s.material,
        render: s.render,
        onCount: onCount,
        count: c.count,
        roundSize: c.target,
        animate: !reduce,
      ),
      TasbihStyle.lcd => LcdCounterView(
        count: c.count,
        rounds: c.rounds,
        onCount: onCount,
        onReset: ref.read(tasbihCounterProvider.notifier).reset,
        animate: !reduce,
      ),
      _ => PressButtonView(
        onCount: onCount,
        progress: progress,
        large: elderly,
        animate: !reduce,
      ),
    };
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final area = Semantics(
      button: true,
      label: l.tasbihCountAction,
      value: c.target == null
          ? digits(c.count)
          : l.tasbihCountOf(digits(c.count), digits(c.target!)),
      onTap: onCount,
      excludeSemantics: true,
      child: counter,
    );
    final info = [
      const DhikrHeader(),
      const SizedBox(height: 12),
      _RoundLine(progress: progress),
      if (s.style != TasbihStyle.lcd) ...[
        const SizedBox(height: 8),
        _CountText(count: c.count, size: elderly ? 88 : 72),
      ],
    ];
    if (context.isExpanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...info,
                  const SizedBox(height: 24),
                  const TargetBar(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(child: area),
          ],
        ),
      );
    }
    final hint = [
      if (s.style == TasbihStyle.misbaha)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l.tasbihDragHint,
            style: TextStyle(color: context.look.sub, fontSize: 13),
          ),
        ),
      const TargetBar(),
    ];
    // Large text: the screen scrolls, and the counter keeps a large,
    // fixed area to tap.
    if (MediaQuery.textScalerOf(context).scale(10) > 13) {
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              ...info,
              SizedBox(
                height: math.max(280, box.maxHeight * 0.55),
                child: area,
              ),
              ...hint,
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          ...info,
          Expanded(child: area),
          ...hint,
        ],
      ),
    );
  }
}

/// The count, in the interface's digits font (not Changa's).
class _CountText extends StatelessWidget {
  const _CountText({required this.count, required this.size, this.color});

  final int count;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final digits = NumberFormatter(Localizations.localeOf(context));
    return Semantics(
      liveRegion: true,
      child: Text(
        digits(count),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: digitsFamily,
          fontSize: size,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: color ?? context.look.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The target and the round, and a thin line of the round's progress.
class _RoundLine extends ConsumerWidget {
  const _RoundLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(tasbihCounterProvider);
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final reduce = MediaQuery.disableAnimationsOf(context);
    final sub = TextStyle(color: look.sub, fontSize: 14);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.target == null
                    ? l.tasbihNoTarget
                    : '${l.tasbihTarget} ${digits(c.target!)}',
                style: sub,
              ),
            ),
            Flexible(
              child: Text(
                l.tasbihRounds(c.rounds, digits(c.rounds)),
                style: sub,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        if (c.target != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: Duration(milliseconds: reduce ? 0 : 220),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                color: look.accent,
                backgroundColor: look.line,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The dhikr being counted; a tap opens the list to choose another.
class DhikrHeader extends ConsumerWidget {
  const DhikrHeader({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dhikr = ref.watch(currentDhikrProvider);
    final l = AppLocalizations.of(context);
    final look = context.look;
    final elderly = look.elderly;
    final Widget body = dhikr == null
        ? Text(l.tasbihEmpty, style: TextStyle(color: look.sub))
        : Column(
            children: [
              _DhikrText(
                dhikr: dhikr,
                style: TextStyle(
                  fontSize: elderly ? 26 : 22,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: color ?? look.ink,
                ),
              ),
              if (dhikr.stages.isNotEmpty) const _StageLine(),
              _DhikrNote(dhikr: dhikr),
            ],
          );
    return Semantics(
      button: true,
      hint: l.tasbihChooseDhikr,
      child: InkWell(
        borderRadius: BorderRadius.circular(look.radius),
        onTap: () => showDhikrSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(child: body),
              Icon(Icons.expand_more, color: look.sub),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dhikr's text as its source has it. For a dhikr said in stages, the
/// span being said now is drawn in the accent colour and the rest quieter.
class _DhikrText extends ConsumerWidget {
  const _DhikrText({required this.dhikr, required this.style});

  final Dhikr dhikr;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = dhikr.text;
    final stage = ref.watch(tasbihCounterProvider.select((c) => c.stage));
    if (dhikr.stages.isEmpty || stage == null) {
      return Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final look = context.look;
    final on = dhikr.stages[stage.index];
    final quiet = style.copyWith(color: look.sub, fontWeight: FontWeight.w400);
    return Text.rich(
      TextSpan(
        style: quiet,
        children: [
          TextSpan(text: text.substring(0, on.start)),
          TextSpan(
            text: text.substring(on.start, on.end),
            style: style.copyWith(color: look.accent),
          ),
          TextSpan(text: text.substring(on.end)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// «٢/٤ · ١٢/٣٣»: the stage, and the count within it.
class _StageLine extends ConsumerWidget {
  const _StageLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(tasbihCounterProvider);
    final stage = c.stage;
    if (stage == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        l.tasbihStageLine(
          digits(stage.index + 1),
          digits(c.stages!.length),
          digits(stage.count),
          digits(stage.of),
        ),
        semanticsLabel:
            '${l.tasbihStageAnnounce(digits(stage.index + 1), digits(c.stages!.length))}، '
            '${l.tasbihCountOf(digits(stage.count), digits(stage.of))}',
        style: TextStyle(
          fontFamily: digitsFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.look.accent,
        ),
      ),
    );
  }
}

class _DhikrNote extends StatelessWidget {
  const _DhikrNote({required this.dhikr});

  final Dhikr dhikr;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final l = AppLocalizations.of(context);
    if (dhikr.mine) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: MineBadge(label: l.tasbihMine),
      );
    }
    final ref = dhikr.reference;
    if (ref == null) return const SizedBox.shrink();
    return Text(
      ref,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: look.sub, fontSize: 12),
    );
  }
}

/// «من إضافتك».
class MineBadge extends StatelessWidget {
  const MineBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: look.accent.withValues(alpha: .5)),
      ),
      child: Text(label, style: TextStyle(color: look.accent, fontSize: 12)),
    );
  }
}

/// The round's target: 33, 100 or none in one tap, any other with ±, and
/// starting the round again.
class TargetBar extends ConsumerWidget {
  const TargetBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final target = ref.watch(tasbihSettingsProvider.select((s) => s.target));
    final ctrl = ref.read(tasbihSettingsProvider.notifier);
    final big = look.elderly;
    final button = big ? 56.0 : 48.0;
    final staged = ref.watch(currentDhikrProvider)?.stages.isNotEmpty ?? false;
    if (staged) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              l.tasbihStagesFixed,
              textAlign: TextAlign.center,
              style: TextStyle(color: look.sub),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: button,
            child: IconButton(
              key: const ValueKey('tasbih-reset-button'),
              icon: const Icon(Icons.restart_alt),
              tooltip: l.tasbihReset,
              onPressed: ref.read(tasbihCounterProvider.notifier).reset,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tasbihPresetTargets)
              ChoiceChip(
                label: Text(t == null ? l.tasbihNoTarget : digits(t)),
                selected: target == t,
                onSelected: (_) => ctrl.setTarget(t),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: button,
              child: IconButton.outlined(
                icon: const Icon(Icons.remove),
                tooltip: l.tasbihTargetLess,
                onPressed: target == null
                    ? null
                    : () => ctrl.setTarget(stepTarget(target, up: false)),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                target == null ? '—' : digits(target),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: digitsFamily,
                  fontSize: big ? 30 : 24,
                  fontWeight: FontWeight.w600,
                  color: look.ink,
                ),
              ),
            ),
            SizedBox.square(
              dimension: button,
              child: IconButton.outlined(
                icon: const Icon(Icons.add),
                tooltip: l.tasbihTargetMore,
                onPressed: () => ctrl.setTarget(stepTarget(target, up: true)),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox.square(
              dimension: button,
              child: IconButton(
                key: const ValueKey('tasbih-reset-button'),
                icon: const Icon(Icons.restart_alt),
                tooltip: l.tasbihReset,
                onPressed: ref.read(tasbihCounterProvider.notifier).reset,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// «الشاشة كلها»: any touch counts, a swipe down leaves. In the theme's
/// own colours, quiet: the dhikr, the count and the target only.
class _WholeScreen extends ConsumerWidget {
  const _WholeScreen({required this.onCount, required this.closing});

  final VoidCallback onCount;
  final bool closing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(tasbihCounterProvider);
    final look = context.look;
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final calm = look.sub;
    var drag = 0.0;
    return Semantics(
      button: true,
      label: l.tasbihCountAction,
      value: c.target == null
          ? digits(c.count)
          : l.tasbihCountOf(digits(c.count), digits(c.target!)),
      onTap: onCount,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCount,
        onLongPress: ref.read(tasbihCounterProvider.notifier).reset,
        onVerticalDragStart: (_) => drag = 0,
        onVerticalDragUpdate: (d) => drag += d.delta.dy,
        onVerticalDragEnd: (_) {
          if (drag > 120) Navigator.of(context).maybePop();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            children: [
              ExcludeSemantics(child: DhikrHeader(color: calm)),
              const Spacer(),
              _CountText(
                count: c.count,
                size: look.elderly ? 140 : 120,
                color: look.ink.withValues(alpha: .8),
              ),
              if (c.target != null)
                Text(
                  l.tasbihCountOf('', digits(c.target!)).trim(),
                  style: TextStyle(color: calm, fontSize: 16),
                ),
              const SizedBox(height: 8),
              Text(
                l.tasbihRounds(c.rounds, digits(c.rounds)),
                style: TextStyle(color: calm, fontSize: 14),
              ),
              if (closing)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(Icons.check_circle_outline, color: look.accent),
                ),
              const Spacer(),
              Text(
                l.tasbihScreenHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: calm, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
