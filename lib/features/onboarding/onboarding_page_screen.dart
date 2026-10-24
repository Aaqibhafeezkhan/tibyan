import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import '../settings/theme_picker.dart';
import 'onboarding_frame.dart';
import 'page_preview.dart';

/// First launch, step 3: how the mushaf page looks (plain, without a frame,
/// unless chosen otherwise), with a real page in the chosen look and light.
class OnboardingPageScreen extends ConsumerWidget {
  const OnboardingPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final registry = ref.watch(themeRegistryProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final style = registry.byId(settings.styleId);
    final mode = settings.resolveMode(MediaQuery.platformBrightnessOf(context));
    final look = context.look;
    return OnboardingFrame(
      step: OnboardingStep.page,
      title: l.onbPageTitle,
      hint: l.onbStyleHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: RealPagePreview(
              style: style,
              mode: mode,
              width: 220,
              semanticLabel: style.localizedName(lang),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            style.localizedDescription(lang),
            textAlign: TextAlign.center,
            style: TextStyle(color: look.sub, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          const ThemePicker(columns: 5),
        ],
      ),
    );
  }
}
