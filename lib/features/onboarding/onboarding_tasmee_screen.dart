import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/interface_style.dart';
import '../../l10n/app_localizations.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../tasmee/presentation/tasmee_settings_screen.dart'
    show tasmeeModelInfoProvider;
import 'background_downloads.dart';
import 'onboarding_frame.dart';

/// First launch, step 6: the recitation check's speech model: its size,
/// the Wi‑Fi note and where its source is credited, then a download that
/// carries on in the background, or a skip.
class OnboardingTasmeeScreen extends ConsumerWidget {
  const OnboardingTasmeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final manifest = ref.watch(tasmeeManifestProvider).value;
    final installed = ref.watch(tasmeeModelInfoProvider).value?.$1 != null;
    final download = ref.watch(tasmeeModelDownloadProvider);
    final started = download != null && !download.failed;
    final ready = installed || (download?.done ?? false);

    Future<void> downloadAndStart() async {
      final m = manifest ?? await ref.read(tasmeeManifestProvider.future);
      if (m != null) {
        ref.read(tasmeeModelDownloadProvider.notifier).start(m);
      }
      if (context.mounted) await finishOnboarding(context, ref);
    }

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: look.goldText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: look.sub, height: 1.5)),
          ),
        ],
      ),
    );

    final size = manifest == null
        ? l.tasmeeModelSizeUnknown
        : l.tasmeeModelSize(
            digits((manifest.totalBytes / (1024 * 1024)).round()),
          );

    return OnboardingFrame(
      step: OnboardingStep.tasmee,
      title: l.onbTasmeeTitle,
      nextLabel: ready || started ? l.onbStart : l.onbTasmeeDownload,
      onNext: ready || started
          ? () => finishOnboarding(context, ref)
          : downloadAndStart,
      secondary: ready || started
          ? null
          : TextButton(
              key: const ValueKey('onboarding-skip-step'),
              onPressed: () => finishOnboarding(context, ref),
              child: Text(l.onbSkip),
            ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: look.control,
                      borderRadius: BorderRadius.circular(look.radius / 1.5),
                    ),
                    child: Icon(Icons.graphic_eq, color: look.onControl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ready
                          ? l.onbTasmeeReady
                          : started
                          ? l.onbTasmeeDownloading(
                              digits((download.fraction * 100).round()),
                            )
                          : size,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: look.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.onbTasmeeBody,
                style: TextStyle(color: look.ink, height: 1.6),
              ),
              if (download?.failed ?? false)
                line(Icons.error_outline, l.onbTasmeeFailed),
              line(Icons.wifi, l.tasmeeModelWifiNote),
              line(Icons.lock_outline, l.tasmeeModelVoiceStays),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('onboarding-model-sources'),
                  onPressed: () => context.push('/mushaf/about'),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: Text(l.tasmeeModelDetails),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
