import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/content_database.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import '../audio/player_bar.dart' show reciterLabel;
import '../audio/recitation.dart';
import '../audio/reciter_avatar.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import 'background_downloads.dart';
import 'onboarding_frame.dart';

/// First launch, step 5: one suggested reciter, offered for the whole
/// mushaf offline. The download carries on in the background; any other
/// reciter can be chosen, and every one streams without a download.
class OnboardingReciterScreen extends ConsumerStatefulWidget {
  const OnboardingReciterScreen({super.key});

  @override
  ConsumerState<OnboardingReciterScreen> createState() =>
      _OnboardingReciterScreenState();
}

class _OnboardingReciterScreenState
    extends ConsumerState<OnboardingReciterScreen> {
  bool _choosing = false;

  void _next() => context.go(OnboardingStep.reciter.next!.location);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final reciter = ref.watch(currentReciterProvider).value;
    final download = ref.watch(fullMushafAudioProvider);
    final downloading =
        download != null && reciter != null && download.reciterId == reciter.id;

    return OnboardingFrame(
      step: OnboardingStep.reciter,
      title: l.onbReciterTitle,
      nextLabel: reciter == null || downloading
          ? null
          : l.onbReciterSuggest(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? reciter.nameAr
                  : reciter.nameEn,
            ),
      onNext: reciter == null || downloading
          ? _next
          : () {
              ref.read(fullMushafAudioProvider.notifier).start(reciter);
              _next();
            },
      secondary: downloading
          ? null
          : TextButton(
              key: const ValueKey('onboarding-skip-step'),
              onPressed: _next,
              child: Text(l.onbSkip),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reciter != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ReciterAvatar(
                      id: reciter.id,
                      name: reciterLabel(context, reciter),
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reciterLabel(context, reciter),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: look.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            downloading
                                ? l.onbDownloadingBg(
                                    digits(download.done),
                                    digits(114),
                                  )
                                : l.onbReciterSize(digits(fullMushafAudioMb)),
                            style: TextStyle(color: look.sub, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.wifi_tethering, size: 18, color: look.goldText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.onbReciterOnline,
                  style: TextStyle(color: look.sub, height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_choosing)
            OutlinedButton.icon(
              key: const ValueKey('onboarding-other-reciter'),
              onPressed: () => setState(() => _choosing = true),
              icon: const Icon(Icons.people_outline),
              label: Text(l.onbReciterOther),
            )
          else
            _ReciterList(selected: reciter?.id),
        ],
      ),
    );
  }
}

class _ReciterList extends ConsumerWidget {
  const _ReciterList({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reciters = ref.watch(recitersProvider).value ?? const <ReciterRow>[];
    return Card(
      child: RadioGroup<int>(
        groupValue: selected,
        onChanged: (id) {
          final r = reciters.where((r) => r.id == id).firstOrNull;
          if (r == null) return;
          ref
              .read(settingsProvider.notifier)
              .setReciter(
                r.id,
                riwaya: Riwaya.values.asNameMap()[r.riwaya] ?? Riwaya.hafs,
              );
        },
        child: Column(
          children: [
            for (final r in reciters)
              RadioListTile<int>(
                value: r.id,
                secondary: ReciterAvatar(
                  id: r.id,
                  name: reciterLabel(context, r),
                  size: 36,
                ),
                title: Text(reciterLabel(context, r)),
              ),
          ],
        ),
      ),
    );
  }
}
