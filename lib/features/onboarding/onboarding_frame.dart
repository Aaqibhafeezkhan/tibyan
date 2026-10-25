import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';
import '../mushaf/mushaf_providers.dart';
import '../../core/ui/responsive.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;

/// The first-run steps, in order. Each lives at `/onboarding/<name>`.
enum OnboardingStep {
  language,
  style,
  page,
  pageTurn,
  edition,
  reciter,
  tasmee;

  String get location => '/onboarding/$name';

  OnboardingStep? get next =>
      index + 1 < values.length ? values[index + 1] : null;

  OnboardingStep? get previous => index > 0 ? values[index - 1] : null;
}

/// Ends the first run: marks it done (and the «what's new» as seen) and
/// opens home, or the edition's download when its pages are not on the
/// device yet. Whatever was not chosen keeps its default.
Future<void> finishOnboarding(BuildContext context, WidgetRef ref) async {
  await ref.read(settingsProvider.notifier).completeOnboarding();
  if (!context.mounted) return;
  final edition = ref.read(settingsProvider).edition;
  final onDevice = ref.read(installedEditionsProvider).contains(edition);
  context.go(onDevice ? '/' : '/mushaf/download');
  markAppRouterReady(ref.read(appRouterReadyProvider));
}

/// The frame of a first-run step: where the reader is (a bar of seven
/// marks), «تخطَّ الكل», the title, the step's body, and the next button
/// held at the bottom within the thumb's reach.
class OnboardingFrame extends ConsumerWidget {
  const OnboardingFrame({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.hint,
    this.nextLabel,
    this.onNext,
    this.secondary,
    this.nextEnabled = true,
  });

  final OnboardingStep step;
  final String title;
  final String? hint;
  final Widget child;

  /// The main button's label: «متابعة» by default.
  final String? nextLabel;

  /// The main button's action: the next step by default.
  final VoidCallback? onNext;

  /// False greys the main button out (nothing to do yet).
  final bool nextEnabled;

  /// A quieter action under the main button («تخطَّ»).
  final Widget? secondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final total = OnboardingStep.values.length;
    void next() {
      final n = step.next;
      if (n == null) {
        finishOnboarding(context, ref);
      } else {
        context.go(n.location);
      }
    }

    return LookScaffold(
      rail: false,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.narrow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      if (step.previous case final p?)
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => context.go(p.location),
                          icon: const BackButtonIcon(),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Semantics(
                          label: l.onbStepOf(
                            digits(step.index + 1),
                            digits(total),
                          ),
                          child: ExcludeSemantics(
                            child: _StepMarks(
                              current: step.index,
                              total: total,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('onboarding-skip-all'),
                        onPressed: () => finishOnboarding(context, ref),
                        child: Text(l.onbSkipAll),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: TibyanWordmark(
                            color: look.goldText,
                            height: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: lookTitleStyle(context, size: 22),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            hint!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: look.sub, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 20),
                        child,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        key: const ValueKey('onboarding-next'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: nextEnabled ? onNext ?? next : null,
                        child: Text(
                          textAlign: TextAlign.center,
                          nextLabel ??
                              (step.next == null
                                  ? l.onbStart
                                  : l.continueLabel),
                        ),
                      ),
                      ?secondary,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seven short bars: the steps done in gold, this one in the control colour
/// and longer, the rest as hairlines.
class _StepMarks extends StatelessWidget {
  const _StepMarks({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 26 : 12,
              height: 6,
              decoration: BoxDecoration(
                color: i == current
                    ? look.control
                    : i < current
                    ? look.gold
                    : look.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
