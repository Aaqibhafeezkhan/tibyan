import 'package:flutter/material.dart';

import '../../core/ui/look_kit.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/content_database.dart';
import '../../core/settings/app_settings.dart';
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

/// «الاستماع»: choose a reciter, play any surah (from the device, or
/// streamed), and download surahs for listening offline. Surahs saved
/// while listening are listed as downloaded. The player's controls show
/// at the foot of the screen while a surah plays (GlobalPlayer).
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

  /// The reciter chosen on this screen, of any riwaya; until one is
  /// chosen, the one playing, else the reader's choice for the mushaf.
  int? _chosen = _last;

  /// The last reciter chosen here, kept while the app runs: leaving the
  /// screen and coming back finds the same reciter chosen.
  static int? _last;

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahsProvider).value;
    final all = ref.watch(allRecitersProvider).value;
    final fallback = ref.watch(playingReciterProvider).value;
    final reciter = all?.where((r) => r.id == _chosen).firstOrNull ?? fallback;
    if (reciter == null || surahs == null || all == null) {
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
          _build(context, reciter, surahs, files.downloaded(reciter.id), all),
    );
  }

  Widget _build(
    BuildContext context,
    ReciterRow reciter,
    List<SurahRow> surahs,
    Set<int> have,
    List<ReciterRow> all,
  ) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final files = ref.read(audioFilesProvider);
    final bg = ref.read(backgroundRecitationsProvider);
    final queued = _anyQueued(bg, reciter.id);
    final paused = bg.paused(reciter.id);
    final playing = ref.watch(recitationProvider);
    final c = ref.read(recitationProvider.notifier);
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.sectionListen),
            _ReciterPicker(
              all: all,
              chosen: reciter,
              onChoose: (r) {
                setState(() => _chosen = _last = r.id);
                // Listening already: the new reciter carries on (the same
                // surah, from the same verse within the mushaf's riwaya).
                if (!playing.active || playing.clip != null) return;
                final riwaya = ref.read(editionProvider).riwaya;
                if (r.riwaya == riwaya.name && !playing.foreign) {
                  c.changeReciter(r.id);
                } else {
                  c.play(playing.surah, reciter: r);
                }
              },
            ),
            // The reciter's line scrolls with the surahs, so large text
            // keeps the list on the screen.
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: 116,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return ListTile(
                            leading: ReciterAvatar(
                              id: reciter.id,
                              name: reciterLabel(context, reciter),
                              size: 38,
                            ),
                            title: Text(reciterLabel(context, reciter)),
                            subtitle: Text(
                              '${l.audioDownloaded}: ${digits(have.length)} / ${digits(114)}',
                            ),
                            trailing: queued
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        key: const ValueKey('audio-all-toggle'),
                                        onPressed: () => paused
                                            ? bg.resumeReciter(reciter.id)
                                            : bg.pauseReciter(reciter.id),
                                        child: Text(
                                          paused
                                              ? l.audioDownloadResume
                                              : l.pause,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l.cancel,
                                        onPressed: () =>
                                            bg.cancelReciter(reciter.id),
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
                          );
                        }
                        if (i == 1) return const Divider(height: 1);
                        final n = i - 1;
                        final done = have.contains(n);
                        final name = surahName(context, surahs[n - 1]);
                        final current =
                            playing.active &&
                            playing.clip == null &&
                            playing.surah == n;
                        return ListTile(
                          key: ValueKey('listen-surah-$n'),
                          selected: current,
                          selectedTileColor: t.control.withValues(alpha: .08),
                          // A tap plays the surah (or pauses and resumes it
                          // when it is the one playing); streamed when it
                          // is not on the device.
                          onTap: () => current
                              ? c.toggle()
                              : c.play(n, reciter: reciter),
                          leading: SizedBox(
                            width: 36,
                            child: Center(
                              child: current
                                  ? Icon(
                                      playing.playing
                                          ? Icons.graphic_eq
                                          : Icons.pause,
                                      color: t.control,
                                      semanticLabel: l.listenNowPlaying,
                                    )
                                  : Text(
                                      digits(n),
                                      style: TextStyle(color: t.muted),
                                    ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: current
                                ? const TextStyle(fontWeight: FontWeight.w700)
                                : null,
                          ),
                          subtitle: current && playing.ayah != null
                              ? Text(
                                  '${l.listenNowPlaying} | ${digits(playing.ayah!)}',
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: current && playing.playing
                                    ? l.pause
                                    : l.playSurahNamed(name),
                                onPressed: () => current
                                    ? c.toggle()
                                    : c.play(n, reciter: reciter),
                                icon: Icon(
                                  current && playing.playing
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_outline,
                                  color: t.control,
                                ),
                              ),
                              _downloadButton(
                                l,
                                t,
                                bg,
                                files,
                                reciter,
                                n,
                                name,
                                done,
                              ),
                            ],
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

  Widget _downloadButton(
    AppLocalizations l,
    dynamic t,
    BackgroundRecitations bg,
    dynamic files,
    ReciterRow reciter,
    int n,
    String name,
    bool done,
  ) {
    if (bg.queued(reciter.id, n) || files.downloading(reciter.id, n)) {
      return SizedBox.square(
        dimension: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: l.downloadingSurah(name),
            ),
          ),
        ),
      );
    }
    if (done) {
      return IconButton(
        tooltip: l.deleteSurahDownload(name),
        icon: Icon(Icons.check_circle, color: t.control),
        onPressed: () => setState(() => files.delete(reciter.id, n)),
      );
    }
    return IconButton(
      tooltip: bg.failed(reciter.id, n)
          ? l.retryDownloadSurah(name)
          : l.downloadSurah(name),
      icon: Icon(
        bg.failed(reciter.id, n)
            ? Icons.error_outline
            : Icons.download_outlined,
      ),
      onPressed: () => _download(reciter, n),
    );
  }
}

/// Every recitation, in a row per riwaya: the mushaf's riwaya first, then
/// the others, each under its name. Those of another riwaya play here,
/// on this screen, with a note that the mushaf does not follow them.
class _ReciterPicker extends ConsumerWidget {
  const _ReciterPicker({
    required this.all,
    required this.chosen,
    required this.onChoose,
  });

  final List<ReciterRow> all;
  final ReciterRow chosen;
  final ValueChanged<ReciterRow> onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final mushaf = ref.watch(editionProvider.select((e) => e.riwaya));
    final order = [mushaf, ...Riwaya.values.where((r) => r != mushaf)];
    final groups = [
      for (final riwaya in order)
        (
          riwaya,
          [
            for (final r in all)
              if (r.riwaya == riwaya.name) r,
          ],
        ),
    ].where((g) => g.$2.isNotEmpty).toList();
    final muted = TextStyle(color: t.muted, fontSize: 12);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .42,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 4),
        children: [
          for (final (riwaya, reciters) in groups) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  riwayaName(l, riwaya),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (riwaya != mushaf)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 0),
                child: Text(l.listenOtherRiwayaNote, style: muted),
              ),
            SizedBox(
              // The avatar, and two lines of the name at the text size.
              height: 72 + MediaQuery.textScalerOf(context).scale(32),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                itemCount: reciters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final r = reciters[i];
                  final selected = r.id == chosen.id;
                  final name = reciterLabel(context, r);
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '$name, ${riwayaName(l, riwaya)}',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: selected ? null : () => onChoose(r),
                      child: SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? t.control
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ReciterAvatar(
                                id: r.id,
                                name: name,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ar ? r.nameAr : r.nameEn,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
