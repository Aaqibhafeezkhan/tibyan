import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_frame.dart';
import 'page_turn_preview.dart';

/// First launch: how the mushaf turns its pages (a light fade unless
/// chosen otherwise). Each effect is a small book turning its page over
/// and over; a tap chooses it.
class OnboardingPageTurnScreen extends ConsumerWidget {
  const OnboardingPageTurnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final chosen = ref.watch(settingsProvider.select((s) => s.pageTurn));
    final ctrl = ref.read(settingsProvider.notifier);
    final look = context.look;
    final t = context.tokens.colors;
    final options = [
      (PageTurn.fade, l.pageTurnFade, l.pageTurnFadeHint),
      (PageTurn.normal, l.pageTurnNormal, l.pageTurnNormalHint),
      (PageTurn.curl, l.pageTurnCurl, l.pageTurnCurlHint),
      (PageTurn.bend, l.pageTurnBend, l.pageTurnBendHint),
      (PageTurn.fold, l.pageTurnFold, l.pageTurnFoldHint),
    ];
    return OnboardingFrame(
      step: OnboardingStep.pageTurn,
      title: l.onbPageTurnTitle,
      hint: l.onbStyleHint,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final (effect, name, hint) in options)
                SizedBox(
                  width: w,
                  child: Semantics(
                    button: true,
                    selected: effect == chosen,
                    label: name,
                    hint: hint,
                    excludeSemantics: true,
                    child: Material(
                      color: look.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: effect == chosen ? look.gold : look.line,
                          width: effect == chosen ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('onb-page-turn-${effect.name}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => ctrl.setPageTurn(effect),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                          child: Column(
                            children: [
                              PageTurnPreview(
                                effect: effect,
                                paper: t.paper,
                                ink: t.ink,
                                accent: t.goldText,
                                width: (w - 32).clamp(80, 150),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (effect == chosen) ...[
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: look.goldText,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: look.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hint,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: look.sub,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
