import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/content_database.dart';
import '../../../core/downloads/background_downloads.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/look_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../audio/background_recitations.dart';
import '../../audio/player_bar.dart';
import '../../audio/recitation.dart';
import '../../books/books_providers.dart';
import '../../onboarding/background_downloads.dart';
import '../../search/semantic/meaning_providers.dart';
import '../../tasmee/data/background_model_download.dart';
import '../../tasmee/data/tasmee_backend.dart';
import '../../tasmee/presentation/tasmee_settings_screen.dart'
    show tasmeeModelInfoProvider;
import '../data/page_pack.dart';
import '../mushaf_providers.dart';
import 'background_downloads_list.dart';
import 'widgets/illuminated_frame.dart';
import '../../../core/ui/responsive.dart';

/// The Downloads Center: what is on the device, what is downloading and
/// what can be downloaded, in three sections (the mushafs, the
/// recitations, the resources). Opening it never starts a download: each
/// item has its own button, each section its «download all». Leaving it
/// leaves every download running in the background.
class DownloadsCenterScreen extends ConsumerWidget {
  const DownloadsCenterScreen({super.key});

  /// Whether anything is downloading in the background now.
  static bool _busy(WidgetRef ref) {
    if (ref.read(backgroundDownloadsProvider).tasks.value.isNotEmpty) {
      return true;
    }
    for (final e in MushafEdition.values) {
      final p = ref.read(editionDownloadProvider(e)).phase;
      if (p == PackPhase.downloading ||
          p == PackPhase.verifying ||
          p == PackPhase.installing) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    void leaving() {
      if (_busy(ref)) {
        messenger?.showSnackBar(SnackBar(content: Text(l.downloadsGoesOn)));
      }
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) leaving();
      },
      child: LookScaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              LookTopBar(title: l.downloadAllTitle),
              Expanded(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ContentWidth.text,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const _MushafSection(),
                          const _RecitationsSection(),
                          const _ResourcesSection(),
                          Text(
                            l.downloadInBackgroundNote,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.tokens.colors.muted,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                leaving();
                                context.go('/mushaf');
                              }
                            },
                            child: Text(l.doneLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _mb(BuildContext context, int bytes) =>
    NumberFormatter(Localizations.localeOf(context))
        .decimal((bytes / 1e6).toStringAsFixed(1));

/// A section's heading, with its «download all» when there is something
/// left to download.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onDownloadAll,
    required this.sectionKey,
  });

  final String title;
  final VoidCallback? onDownloadAll;
  final String sectionKey;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  color: t.goldText,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          if (onDownloadAll != null)
            TextButton.icon(
              key: ValueKey('downloads-all-$sectionKey'),
              onPressed: onDownloadAll,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(l.downloadAll),
            ),
        ],
      ),
    );
  }
}

/// A pack the system downloads (an edition, the meaning search, a book).
class _PackRow extends StatelessWidget {
  const _PackRow({
    super.key,
    required this.title,
    required this.progress,
    required this.bytes,
    required this.onStart,
    this.onPause,
  });

  final String title;
  final PackProgress progress;
  final int bytes;
  final VoidCallback onStart;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final p = progress;
    final total = p.total > 0 ? p.total : bytes;
    String mb(int b) => _mb(context, b);
    final fraction = switch (p.phase) {
      PackPhase.downloading || PackPhase.idle => p.received / total,
      PackPhase.verifying || PackPhase.installing => null,
      PackPhase.installed => 1.0,
      PackPhase.failed => p.received / total,
    };
    final status = switch (p.phase) {
      PackPhase.idle when p.received == 0 => l.downloadsAvailable(mb(total)),
      PackPhase.idle ||
      PackPhase.downloading => l.downloadProgress(mb(p.received), mb(total)),
      PackPhase.verifying => l.downloadVerifying,
      PackPhase.installing => l.downloadInstalling,
      PackPhase.installed => l.downloadsOnDevice(mb(total)),
      PackPhase.failed => l.downloadFailed(p.error ?? ''),
    };
    final Widget? action = switch (p.phase) {
      PackPhase.installed => Icon(
        Icons.check_circle,
        color: t.control,
        semanticLabel: l.downloadDone,
      ),
      PackPhase.verifying || PackPhase.installing => null,
      PackPhase.downloading =>
        onPause == null
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: l.downloadPause,
                onPressed: onPause,
                icon: const Icon(Icons.pause),
              ),
      PackPhase.failed => IconButton(
        tooltip: l.downloadRetry,
        onPressed: onStart,
        icon: const Icon(Icons.refresh),
      ),
      PackPhase.idle => IconButton(
        tooltip: p.received > 0 ? l.downloadResume : l.downloadStart,
        onPressed: onStart,
        icon: Icon(p.received > 0 ? Icons.play_arrow : Icons.download),
      ),
    };
    return DownloadRow(
      title: title,
      status: status,
      fraction: fraction,
      done:
          p.phase == PackPhase.installed ||
          (p.phase == PackPhase.idle && p.received == 0),
      actions: [
        SizedBox(
          width: 48,
          child: Center(child: action ?? const SizedBox.shrink()),
        ),
      ],
    );
  }
}

class _MushafSection extends ConsumerWidget {
  const _MushafSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    const editions = MushafEdition.values;
    final missing = [
      for (final e in editions)
        if (ref.watch(editionDownloadProvider(e)).phase == PackPhase.idle ||
            ref.watch(editionDownloadProvider(e)).phase == PackPhase.failed)
          e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          sectionKey: 'mushaf',
          title: l.downloadsSectionMushaf,
          onDownloadAll: missing.isEmpty
              ? null
              : () => ref.read(pageDownloadProvider.notifier).startAll(),
        ),
        for (final e in editions)
          _PackRow(
            key: ValueKey('downloads-edition-${e.name}'),
            title: editionName(l, e),
            progress: ref.watch(editionDownloadProvider(e)),
            bytes: PagePackSpec.of(e).bytes,
            onStart: ref.read(editionDownloadProvider(e).notifier).start,
            onPause: ref.read(editionDownloadProvider(e).notifier).pause,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RecitationsSection extends ConsumerWidget {
  const _RecitationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bg = ref.watch(backgroundRecitationsProvider);
    final downloads = ref.watch(backgroundDownloadsProvider);
    final reciters = ref.watch(recitersProvider).value ?? const <ReciterRow>[];
    return ListenableBuilder(
      listenable: Listenable.merge([downloads.tasks, bg.files.changes]),
      builder: (context, _) {
        final busy = <int>{
          for (final r in downloads.tasks.value.values)
            if (r.group == BackgroundRecitations.kGroup)
              ?BackgroundRecitations.decode(r.task)?.reciter,
        };
        final digits = NumberFormatter(Localizations.localeOf(context));
        Future<void> download(ReciterRow r) => bg.enqueueAll(
          r,
          urls: (s) => ref.read(audioHostsProvider.notifier).urls(r, s),
          displayName: reciterLabel(context, r),
        );
        final rows = <Widget>[];
        for (final r in reciters) {
          if (busy.contains(r.id)) continue;
          final have = bg.files.downloaded(r.id);
          var bytes = 0;
          for (final s in have) {
            try {
              bytes += bg.files.file(r.id, s).lengthSync();
            } on FileSystemException {
              // Removed meanwhile.
            }
          }
          rows.add(
            DownloadRow(
              key: ValueKey('downloads-reciter-${r.id}-idle'),
              title: reciterLabel(context, r),
              fraction: have.length / 114,
              done: true,
              status: have.isEmpty
                  ? l.downloadsAvailableShort
                  : l.downloadsReciterOnDevice(
                      digits(have.length),
                      digits(114),
                      _mb(context, bytes),
                    ),
              actions: [
                SizedBox(
                  width: 48,
                  child: Center(
                    child: have.length == 114
                        ? Icon(
                            Icons.check_circle,
                            color: context.tokens.colors.control,
                            semanticLabel: l.downloadDone,
                          )
                        : IconButton(
                            tooltip: l.downloadStart,
                            onPressed: () => download(r),
                            icon: const Icon(Icons.download),
                          ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No «download all» here: every reciter's whole mushaf would
            // be many gigabytes. Each reciter has its own button.
            _SectionHeader(
              sectionKey: 'recitations',
              title: l.downloadsSectionRecitations,
              onDownloadAll: null,
            ),
            const BackgroundDownloadsList(model: false),
            ...rows,
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _ResourcesSection extends ConsumerWidget {
  const _ResourcesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final model = ref.watch(backgroundModelDownloadProvider);
    final downloads = ref.watch(backgroundDownloadsProvider);
    final info = ref.watch(tasmeeModelInfoProvider).value;
    final semantic = ref.watch(semanticDownloadProvider);
    final books = ref.watch(bookPackSpecsProvider);
    final bookProgress = ref.watch(bookDownloadsProvider);
    final installedBooks = {
      for (final b in ref.watch(installedBookPacksProvider))
        if (b.spec != null) b.spec!.id,
    };
    PackProgress bookState(String id) => installedBooks.contains(id)
        ? const PackProgress(PackPhase.installed)
        : bookProgress[id] ?? const PackProgress(PackPhase.idle);

    Future<void> downloadModel() async {
      final backend = ref.read(tasmeeBackendProvider);
      try {
        final m = await backend.fetchManifest();
        ref.read(tasmeeModelDownloadProvider.notifier).start(m);
      } catch (_) {
        // Offline: the button stays for another try.
      }
    }

    return ListenableBuilder(
      listenable: downloads.tasks,
      builder: (context, _) {
        final modelBusy = model.active != null;
        final modelHere = info?.$1 != null;
        bool idle(PackPhase p) => p == PackPhase.idle || p == PackPhase.failed;
        final anyMissing =
            (!modelBusy && !modelHere) ||
            idle(semantic.phase) ||
            books.any((b) => idle(bookState(b.id).phase));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              sectionKey: 'resources',
              title: l.downloadsSectionResources,
              onDownloadAll: !anyMissing
                  ? null
                  : () {
                      if (!modelBusy && !modelHere) unawaited(downloadModel());
                      if (idle(semantic.phase)) {
                        unawaited(
                          ref.read(semanticDownloadProvider.notifier).start(),
                        );
                      }
                      for (final b in books) {
                        if (idle(bookState(b.id).phase)) {
                          unawaited(
                            ref.read(bookDownloadsProvider.notifier).start(b),
                          );
                        }
                      }
                    },
            ),
            if (modelBusy)
              const BackgroundDownloadsList(recitations: false)
            else
              DownloadRow(
                key: const ValueKey('downloads-tasmee-model-idle'),
                title: l.tasmeeModelTitle,
                fraction: modelHere ? 1 : 0,
                done: true,
                status: modelHere
                    ? l.downloadsOnDevice(_mb(context, info!.$2))
                    : l.downloadsAvailableShort,
                actions: [
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: modelHere
                          ? Icon(
                              Icons.check_circle,
                              color: context.tokens.colors.control,
                              semanticLabel: l.downloadDone,
                            )
                          : IconButton(
                              tooltip: l.downloadStart,
                              onPressed: downloadModel,
                              icon: const Icon(Icons.download),
                            ),
                    ),
                  ),
                ],
              ),
            _PackRow(
              key: const ValueKey('downloads-semantic'),
              title: l.semanticPackName,
              progress: semantic,
              bytes: PagePackSpec.semantic.bytes,
              onStart: () => unawaited(
                ref.read(semanticDownloadProvider.notifier).start(),
              ),
            ),
            for (final b in books)
              _PackRow(
                key: ValueKey('downloads-book-${b.id}'),
                title: b.title,
                progress: bookState(b.id),
                bytes: b.bytes,
                onStart: () => unawaited(
                  ref.read(bookDownloadsProvider.notifier).start(b),
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
