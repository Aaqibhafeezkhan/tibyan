import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_frame.dart';

/// First launch, step 1: interface language. The title is in both
/// languages so it reads before a choice is made; the screen switches
/// language as soon as one is picked.
class OnboardingLanguageScreen extends ConsumerWidget {
  const OnboardingLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final options = [
      (LanguageSetting.ar, l.languageArabic),
      (LanguageSetting.en, l.languageEnglish),
      (LanguageSetting.system, l.languageSystem),
    ];
    return OnboardingFrame(
      step: OnboardingStep.language,
      title: l.onbLanguageTitle,
      child: Card(
        child: RadioGroup<LanguageSetting>(
          groupValue: settings.language,
          onChanged: (v) => v == null ? null : ctrl.setLanguage(v),
          child: Column(
            children: [
              for (final (value, label) in options)
                RadioListTile(
                  value: value,
                  title: Text(
                    label,
                    style: TextStyle(fontSize: 18, color: context.look.ink),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
