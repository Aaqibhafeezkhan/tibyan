import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/db/content_database.dart';
import '../../core/downloads/background_downloads.dart';
import '../mushaf/mushaf_providers.dart';
import 'recitation.dart';
import 'word_timing_packs.dart';

/// A recitation's surahs downloaded by the system, like the edition packs:
/// a whole mushaf in one reciter's voice goes on when the reader leaves the
/// screen or the app, shows in the Downloads screen and in one grouped
/// notification, and can be cancelled or retried. Each surah is one task,
/// from the faster host first, then the other; a finished file is moved
/// to where the player looks for it ([AudioFiles.file]).
class BackgroundRecitations implements DownloadHandler {
  BackgroundRecitations({
    required BackgroundDownloads downloads,
    required this.files,
    this.words,
    Future<Directory> Function()? supportDir,
  }) : _downloads = downloads,
       _supportDir = supportDir ?? getApplicationSupportDirectory {
    downloads.register(this);
  }

  static const kGroup = 'recitations';

  /// Where the files arrive, under the app's support folder.
  static const folder = 'recitation-downloads';

  /// The grouped notification's title, in the interface language.
  static String title = 'تحميل التلاوات';

  final BackgroundDownloads _downloads;
  final AudioFiles files;

  /// The reciter's word timings come with the reciter's audio.
  final WordTimingPacks? words;
  final Future<Directory> Function() _supportDir;
  final _placing = <String>{};

  @override
  String get group => kGroup;

  @override
  get notifications => (
    running: TaskNotification(title, '{numFinished}/{numTotal}'),
    complete: TaskNotification(title, '{numFinished}/{numTotal}'),
    error: TaskNotification(title, '{numFailed}'),
    paused: TaskNotification(title, '{numFinished}/{numTotal}'),
    groupNotificationId: kGroup,
  );

  static String taskIdFor(int reciter, int surah) => 'rec-$reciter-$surah';

  static ({int reciter, int surah, List<String> urls, int source})? decode(
    Task task,
  ) {
    try {
      final j = jsonDecode(task.metaData) as Map<String, dynamic>;
      return (
        reciter: j['r'] as int,
        surah: j['s'] as int,
        urls: [for (final u in j['u'] as List) u as String],
        source: j['i'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  TaskRecord? _record(int reciter, int surah) =>
      _downloads.tasks.value[taskIdFor(reciter, surah)];

  /// Queued or running in the background.
  bool queued(int reciter, int surah) {
    final r = _record(reciter, surah);
    return r != null &&
        r.status != TaskStatus.failed &&
        r.status != TaskStatus.notFound;
  }

  bool failed(int reciter, int surah) {
    final r = _record(reciter, surah);
    return r != null &&
        (r.status == TaskStatus.failed || r.status == TaskStatus.notFound);
  }

  /// Queues one surah unless it is on the device or already queued; one
  /// that failed is tried again.
  Future<void> enqueue(
    ReciterRow reciter,
    int surah, {
    required List<Uri> urls,
    required String displayName,
  }) async {
    if (words?.packed(reciter.id) ?? false) {
      unawaited(words!.ensure(reciter.id));
    }
    if (files.has(reciter.id, surah)) return;
    final id = taskIdFor(reciter.id, surah);
    if (failed(reciter.id, surah)) await _downloads.forget(id);
    if (queued(reciter.id, surah) && await _downloads.taskForId(id) != null) {
      await _downloads.resume(id);
      return;
    }
    await _downloads.enqueue(
      _task(
        reciter: reciter.id,
        surah: surah,
        urls: [for (final u in urls) '$u'],
        source: 0,
        displayName: displayName,
      ),
    );
  }

  /// Queues every surah of [reciter] not yet on the device.
  Future<void> enqueueAll(
    ReciterRow reciter, {
    required List<Uri> Function(int surah) urls,
    required String displayName,
  }) async {
    for (var s = 1; s <= 114; s++) {
      await enqueue(reciter, s, urls: urls(s), displayName: displayName);
    }
  }

  /// Cancels [reciter]'s downloads that have not finished.
  Future<void> cancelReciter(int reciter) => _downloads.cancel([
    for (final r in _downloads.tasks.value.values)
      if (r.group == kGroup && decode(r.task)?.reciter == reciter) r.taskId,
  ]);

  Iterable<TaskRecord> _records(int reciter) => _downloads.tasks.value.values
      .where((r) => r.group == kGroup && decode(r.task)?.reciter == reciter);

  /// Whether [reciter] has surahs queued and every one of them is paused.
  bool paused(int reciter) {
    final rs = _records(reciter).where(
      (r) => r.status != TaskStatus.failed && r.status != TaskStatus.notFound,
    );
    return rs.isNotEmpty && rs.every((r) => r.status == TaskStatus.paused);
  }

  /// Pauses [reciter]'s surahs that are downloading or waiting; a waiting
  /// one is held as paused so it does not start.
  Future<void> pauseReciter(int reciter) async {
    for (final r in _records(reciter).toList()) {
      if (r.status == TaskStatus.running) {
        await _downloads.pause(r.taskId);
      } else if (r.status == TaskStatus.enqueued) {
        await _downloads.hold(r.taskId);
      }
    }
  }

  /// Continues [reciter]'s paused surahs.
  Future<void> resumeReciter(int reciter) async {
    for (final r in _records(reciter).toList()) {
      if (r.status != TaskStatus.paused) continue;
      if (!await _downloads.resume(r.taskId)) {
        // Held before it started (or the system lost it): queue it again.
        final d = decode(r.task);
        await _downloads.forget(r.taskId);
        if (d == null || files.has(d.reciter, d.surah)) continue;
        await _downloads.enqueue(
          _task(
            reciter: d.reciter,
            surah: d.surah,
            urls: d.urls,
            source: d.source,
            displayName: r.task.displayName,
          ),
        );
      }
    }
  }

  /// Queues again [reciter]'s surahs that failed.
  Future<void> retryReciter(int reciter) async {
    for (final r in _downloads.tasks.value.values.toList()) {
      if (r.group != kGroup) continue;
      final d = decode(r.task);
      if (d == null || d.reciter != reciter) continue;
      if (r.status != TaskStatus.failed && r.status != TaskStatus.notFound) {
        continue;
      }
      await _downloads.forget(r.taskId);
      await _downloads.enqueue(
        _task(
          reciter: d.reciter,
          surah: d.surah,
          urls: d.urls,
          source: 0,
          displayName: r.task.displayName,
        ),
      );
    }
  }

  DownloadTask _task({
    required int reciter,
    required int surah,
    required List<String> urls,
    required int source,
    required String displayName,
  }) => DownloadTask(
    taskId: taskIdFor(reciter, surah),
    url: urls[source],
    filename: '$reciter-$surah.mp3',
    directory: folder,
    baseDirectory: BaseDirectory.applicationSupport,
    group: kGroup,
    updates: Updates.statusAndProgress,
    allowPause: true,
    retries: 2,
    displayName: displayName,
    metaData: jsonEncode({'r': reciter, 's': surah, 'u': urls, 'i': source}),
  );

  @override
  Future<void> onUpdate(TaskUpdate update) async {
    final task = update.task;
    if (task is! DownloadTask || update is! TaskStatusUpdate) return;
    switch (update.status) {
      case TaskStatus.complete:
        await _place(task);
      case TaskStatus.failed || TaskStatus.notFound:
        // The other host serves the same file.
        final d = decode(task);
        if (d != null && d.source + 1 < d.urls.length) {
          await _downloads.enqueue(
            _task(
              reciter: d.reciter,
              surah: d.surah,
              urls: d.urls,
              source: d.source + 1,
              displayName: task.displayName,
            ),
          );
        } else {
          files.changes.value++;
        }
      default:
        files.changes.value++;
    }
  }

  @override
  Future<void> onFinishedWhileAway(DownloadTask task) => _place(task);

  Future<void> _place(DownloadTask task) async {
    final d = decode(task);
    if (d == null || !_placing.add(task.taskId)) return;
    try {
      final support = await _supportDir();
      final tmp = File(p.join(support.path, folder, task.filename));
      final target = files.file(d.reciter, d.surah);
      if (!target.existsSync() && tmp.existsSync() && tmp.lengthSync() > 0) {
        target.parent.createSync(recursive: true);
        try {
          tmp.renameSync(target.path);
        } on FileSystemException {
          tmp.copySync(target.path);
          tmp.deleteSync();
        }
      }
      await _downloads.forget(task.taskId);
    } catch (_) {
      // Fetched again when it is played or downloaded next.
      await _downloads.forget(task.taskId);
    } finally {
      _placing.remove(task.taskId);
      files.changes.value++;
    }
  }
}

/// The app's one [BackgroundRecitations].
final backgroundRecitationsProvider = Provider<BackgroundRecitations>(
  (ref) => BackgroundRecitations(
    downloads: ref.watch(backgroundDownloadsProvider),
    files: ref.watch(audioFilesProvider),
    words: ref.watch(wordTimingPacksProvider),
  ),
);
