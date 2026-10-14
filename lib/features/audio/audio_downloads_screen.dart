import 'package:flutter/material.dart';

import '../../core/ui/look_kit.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/content_database.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../mushaf/mushaf_providers.dart';
import '../mushaf/presentation/mushaf_screen.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart';
import '../../core/downloads/background_downloads.dart';
import 'background_recitations.dart';
import 'player_bar.dart';
import 'recitation.dart';
import 'reciter_avatar.dart';

/// Download the chosen reciter's surahs for listening offline. Surahs
/// saved while listening are listed here too, as downloaded.
class AudioDownloadsScreen extends ConsumerStatefulWidget {
  const AudioDownloadsScreen({super.key});

  @override
  ConsumerState<AudioDownloadsScreen> createState() =>
      _AudioDownloadsScreenState();
}

class _AudioDownloadsScreenState extends ConsumerState<AudioDownloadsScreen> {
  // Downloads run on the system's background downloader: they go on when
  // the reader leaves this screen or the app, and show in Downloads.
  Future<void> _download(ReciterRow r, int surah) => ref
      .read(backgroundRecitationsProvider)
      .enqueue(
        r,
        surah,
        urls: ref.read(audioHostsProvider.notifier).urls(r, surah),
        displayName: reciterLabel(context, r),
      );

  Future<void> _downloadAll(ReciterRow r) => ref
      .read(backgroundRecitationsProvider)
      .enqueueAll(
        r,
        urls: (s) => ref.read(audioHostsProvider.notifier).urls(r, s),
        displayName: reciterLabel(context, r),
      );

  bool _anyQueued(BackgroundRecitations bg, int reciter) {
    for (var s = 1; s <= 114; s++) {
      if (bg.queued(reciter, s)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahsProvider).value;
    final reciter = ref.watch(currentReciterProvider).value;
    if (reciter == null || surahs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final files = ref.watch(audioFilesProvider);

    // Saving while listening also ends here: follow it, and the
    // background downloads.
    return ListenableBuilder(
      listenable: Listenable.merge([
        files.changes,
        ref.watch(backgroundDownloadsProvider).tasks,
      ]),
      builder: (context, _) =>
          _build(context, reciter, surahs, files.downloaded(reciter.id)),
    );
  }

  Widget _build(
    BuildContext context,
    ReciterRow reciter,
    List<SurahRow> surahs,
    Set<int> have,
  ) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final files = ref.read(audioFilesProvider);
    final bg = ref.read(backgroundRecitationsProvider);
    final all = _anyQueued(bg, reciter.id);
    final paused = bg.paused(reciter.id);
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.audioDownloads),
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    leading: ReciterAvatar(
                      id: reciter.id,
                      name: reciterLabel(context, reciter),
                      size: 38,
                    ),
                    title: Text(reciterLabel(context, reciter)),
                    subtitle: Text(
                      '${l.audioDownloaded}: ${digits(have.length)} / ${digits(114)}',
                    ),
                    trailing: all
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                key: const ValueKey('audio-all-toggle'),
                                onPressed: () => paused
                                    ? bg.resumeReciter(reciter.id)
                                    : bg.pauseReciter(reciter.id),
                                child: Text(
                                  paused ? l.audioDownloadResume : l.pause,
                                ),
                              ),
                              IconButton(
                                tooltip: l.cancel,
                                onPressed: () => bg.cancelReciter(reciter.id),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          )
                        : FilledButton.tonal(
                            onPressed: have.length == 114
                                ? null
                                : () => _downloadAll(reciter),
                            child: Text(l.downloadAll),
                          ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 114,
                      itemBuilder: (context, i) {
                        final n = i + 1;
                        final done = have.contains(n);
                        return ListTile(
                          dense: true,
                          leading: Text(
                            digits(n),
                            style: TextStyle(color: t.muted),
                          ),
                          title: Text(surahName(context, surahs[i])),
                          trailing:
                              bg.queued(reciter.id, n) ||
                                  files.downloading(reciter.id, n)
                              ? SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: l.downloadingSurah(
                                      surahName(context, surahs[i]),
                                    ),
                                  ),
                                )
                              : done
                              ? IconButton(
                                  tooltip: l.deleteSurahDownload(
                                    surahName(context, surahs[i]),
                                  ),
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: t.control,
                                  ),
                                  onPressed: () => setState(
                                    () => files.delete(reciter.id, n),
                                  ),
                                )
                              : IconButton(
                                  tooltip: bg.failed(reciter.id, n)
                                      ? l.retryDownloadSurah(
                                          surahName(context, surahs[i]),
                                        )
                                      : l.downloadSurah(
                                          surahName(context, surahs[i]),
                                        ),
                                  icon: Icon(
                                    bg.failed(reciter.id, n)
                                        ? Icons.error_outline
                                        : Icons.download_outlined,
                                  ),
                                  onPressed: () => _download(reciter, n),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
