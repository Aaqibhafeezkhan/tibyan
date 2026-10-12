import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_screen.dart' show InterfaceStylePicker;
import 'onboarding_frame.dart';

/// First launch, step 2: the interface style («هندسي» unless chosen
/// otherwise) and its light, and the larger print of elderly mode.
class OnboardingStyleScreen extends ConsumerWidget {
  const OnboardingStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final look = context.look;
    const modes = [
      ModeSetting.light,
      ModeSetting.white,
      ModeSetting.night,
      ModeSetting.black,
    ];
    final modeNames = [l.modeLight, l.modeWhite, l.modeNight, l.modeBlack];
    return OnboardingFrame(
      step: OnboardingStep.style,
      title: l.onbInterfaceTitle,
      hint: l.onbStyleHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(child: InterfaceStylePicker()),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.modeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: look.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ModeSetting>(
                      segments: [
                        for (var i = 0; i < modes.length; i++)
                          ButtonSegment(
                            value: modes[i],
                            label: Text(modeNames[i]),
                          ),
                      ],
                      selected: {
                        settings.mode == ModeSetting.system
                            ? ModeSetting.light
                            : settings.mode,
                      },
                      onSelectionChanged: (v) => ctrl.setMode(v.first),
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.elderly),
              title: Text(l.elderlyMode),
              subtitle: Text(
                l.elderlyModeHint,
                style: TextStyle(color: look.sub),
              ),
              value: settings.elderlyMode,
              onChanged: ctrl.setElderlyMode,
            ),
          ),
        ],
      ),
    );
  }
}
