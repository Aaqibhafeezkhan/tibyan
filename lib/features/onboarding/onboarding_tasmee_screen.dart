import 'package:flutter/foundation.dart';
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

/// Whether this platform can run the recitation check (the speech model
/// and the background downloader): every app build but the web one.
final tasmeeSupportedProvider = Provider<bool>((ref) => !kIsWeb);

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
    final supported = ref.watch(tasmeeSupportedProvider);
    final manifestState = ref.watch(tasmeeManifestProvider);
    final manifest = manifestState.value;
    // The fetch failed (offline, server down): said so, with a retry,
    // instead of a download button that silently does nothing.
    final manifestFailed =
        manifestState.hasError ||
        (!manifestState.isLoading && manifest == null);
    final installed = ref.watch(tasmeeModelInfoProvider).value?.$1 != null;
    final download = ref.watch(tasmeeModelDownloadProvider);
    final failed = download?.failed ?? false;
    final started = download != null && !failed;
    final ready = installed || (download?.done ?? false);
    final done = !supported || ready || started;

    void retryManifest() => ref.invalidate(tasmeeManifestProvider);

    Future<void> downloadAndStart() async {
      final m = manifest;
      if (m == null) return;
      ref.read(tasmeeModelDownloadProvider.notifier).start(m);
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

    final size = manifest != null
        ? l.tasmeeModelSize(
            digits((manifest.totalBytes / (1024 * 1024)).round()),
          )
        : manifestState.isLoading && !manifestState.hasError
        ? l.onbTasmeeChecking
        : l.tasmeeModelSizeUnknown;

    Widget retry(VoidCallback onPressed) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        key: const ValueKey('onboarding-tasmee-retry'),
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(l.downloadRetry),
      ),
    );

    return OnboardingFrame(
      step: OnboardingStep.tasmee,
      title: l.onbTasmeeTitle,
      nextLabel: done ? l.onbStart : l.onbTasmeeDownload,
      onNext: done ? () => finishOnboarding(context, ref) : downloadAndStart,
      nextEnabled: done || manifest != null,
      secondary: done
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
                      !supported
                          ? l.onbTasmeeUnsupported
                          : ready
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
              if (supported &&
                  !ready &&
                  !started &&
                  manifestState.isLoading &&
                  !manifestFailed)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (supported && !ready && !started && manifestFailed) ...[
                line(Icons.cloud_off_outlined, l.onbTasmeeManifestFailed),
                retry(retryManifest),
              ],
              if (supported && failed && !ready && manifest != null) ...[
                line(Icons.error_outline, l.onbTasmeeFailed),
                retry(
                  () => ref
                      .read(tasmeeModelDownloadProvider.notifier)
                      .start(manifest),
                ),
              ],
              if (supported) ...[
                line(Icons.wifi, l.tasmeeModelWifiNote),
                line(Icons.lock_outline, l.tasmeeModelVoiceStays),
              ],
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
