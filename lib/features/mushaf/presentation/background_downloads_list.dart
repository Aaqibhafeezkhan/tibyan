import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/downloads/background_downloads.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../audio/background_recitations.dart';
import '../../tasmee/data/background_model_download.dart';
import '../../tasmee/data/model_manifest.dart';
import 'widgets/illuminated_frame.dart';

/// The downloads the system runs besides the editions (the recognition
/// model, recitations), each with its progress and pause / resume / retry
/// / cancel. Nothing when there are none.
class BackgroundDownloadsList extends ConsumerWidget {
  const BackgroundDownloadsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(backgroundDownloadsProvider);
    final model = ref.watch(backgroundModelDownloadProvider);
    final recitations = ref.watch(backgroundRecitationsProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        downloads.tasks,
        recitations.files.changes,
      ]),
      builder: (context, _) {
        final records = downloads.tasks.value.values;
        final manifest = model.active;
        final byReciter = <int, List<TaskRecord>>{};
        for (final r in records) {
          if (r.group != BackgroundRecitations.kGroup) continue;
          final d = BackgroundRecitations.decode(r.task);
          if (d != null) (byReciter[d.reciter] ??= []).add(r);
        }
        return Column(
          children: [
            if (manifest != null)
              _ModelRow(
                manifest: manifest,
                records: [
                  for (final r in records)
                    if (r.group == BackgroundModelDownload.kGroup) r,
                ],
                model: model,
              ),
            for (final e in byReciter.entries)
              _ReciterRow(reciter: e.key, records: e.value, bg: recitations),
          ],
        );
      },
    );
  }
}

bool _failed(TaskRecord r) =>
    r.status == TaskStatus.failed || r.status == TaskStatus.notFound;

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    required this.status,
    required this.fraction,
    required this.actions,
  });

  final String title;
  final String status;
  final double? fraction;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: '$title. $status',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: fraction, minHeight: 6),
                      const SizedBox(height: 6),
                      Text(
                        status,
                        style: TextStyle(color: t.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.manifest,
    required this.records,
    required this.model,
  });

  final ModelManifest manifest;
  final List<TaskRecord> records;
  final BackgroundModelDownload model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String mb(int bytes) =>
        NumberFormatter(Localizations.localeOf(context))
            .decimal((bytes / 1e6).toStringAsFixed(1));
    // Files already checked have left the list: count them as done.
    final pending = {for (final r in records) r.taskId: r};
    var received = 0.0;
    for (final f in manifest.files) {
      final r = pending[BackgroundModelDownload.taskIdFor(manifest, f)];
      received += f.bytes * (r == null ? 1 : r.progress.clamp(0, 1));
    }
    final total = manifest.totalBytes;
    final failed = records.any(_failed);
    final paused =
        records.isNotEmpty &&
        records.every((r) => r.status == TaskStatus.paused);
    return _Row(
      key: const ValueKey('downloads-tasmee-model'),
      title: l.tasmeeModelTitle,
      fraction: total == 0 ? null : received / total,
      status: failed
          ? l.downloadFailed('')
          : l.downloadProgress(mb(received.round()), mb(total)),
      actions: [
        if (failed)
          IconButton(
            tooltip: l.downloadRetry,
            onPressed: model.retry,
            icon: const Icon(Icons.refresh),
          )
        else if (paused)
          IconButton(
            tooltip: l.downloadResume,
            onPressed: model.resume,
            icon: const Icon(Icons.play_arrow),
          )
        else
          IconButton(
            tooltip: l.downloadPause,
            onPressed: model.pause,
            icon: const Icon(Icons.pause),
          ),
        IconButton(
          tooltip: l.cancel,
          onPressed: model.cancel,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _ReciterRow extends StatelessWidget {
  const _ReciterRow({
    required this.reciter,
    required this.records,
    required this.bg,
  });

  final int reciter;
  final List<TaskRecord> records;
  final BackgroundRecitations bg;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final done = bg.files.downloaded(reciter).length;
    final failed = records.any(_failed);
    return _Row(
      key: ValueKey('downloads-reciter-$reciter'),
      title: records.first.task.displayName,
      fraction: done / 114,
      status: failed
          ? l.downloadFailed('')
          : '${l.audioDownloaded}: ${digits(done)} / ${digits(114)}',
      actions: [
        if (failed)
          IconButton(
            tooltip: l.downloadRetry,
            onPressed: () => bg.retryReciter(reciter),
            icon: const Icon(Icons.refresh),
          ),
        IconButton(
          tooltip: l.cancel,
          onPressed: () => bg.cancelReciter(reciter),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
