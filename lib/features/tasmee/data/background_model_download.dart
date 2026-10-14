import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/downloads/background_downloads.dart';
import 'model_downloader.dart';
import 'model_manifest.dart';
import 'model_store.dart';

/// The recognition model downloaded by the system, like the edition packs:
/// it goes on when the reader leaves the sheet or the app, shows in the
/// Downloads screen and in a notification, and can be paused, resumed,
/// retried or cancelled.
///
/// Each file of the manifest is one task, fetched into a folder of its own
/// and kept only when its size and SHA-256 match the manifest; the model is
/// marked installed (and older ones removed) once every file is in place.
class BackgroundModelDownload implements DownloadHandler {
  BackgroundModelDownload({
    required BackgroundDownloads downloads,
    required this.modelStore,
    Future<Directory> Function()? supportDir,
  }) : _downloads = downloads,
       _supportDir = supportDir ?? getApplicationSupportDirectory {
    downloads.register(this);
  }

  static const kGroup = 'tasmee-download';

  /// Where the files arrive, under the app's support folder.
  static const folder = 'model-downloads';

  /// The model's name in notifications, in the interface language.
  static String displayName = 'نموذج التسميع';

  final BackgroundDownloads _downloads;
  final Future<ModelStore> Function() modelStore;
  final Future<Directory> Function() _supportDir;

  /// Bumped when a model is installed, for screens to follow.
  final installs = ValueNotifier<int>(0);

  final _progress =
      StreamController<(String, ModelDownloadProgress)>.broadcast();
  final _waiters = <String, Completer<InstalledModel>>{};
  final _fractions = <String, double>{};
  final _placing = <String>{};

  @override
  String get group => kGroup;

  @override
  get notifications => (
    running: TaskNotification('{displayName}', '{progress}'),
    complete: TaskNotification('{displayName}', ''),
    error: TaskNotification('{displayName}', ''),
    paused: TaskNotification('{displayName}', ''),
    groupNotificationId: '',
  );

  static String _key(ModelManifest m) => '${m.id}@${m.version}';

  static String taskIdFor(ModelManifest m, ModelFileSpec f) =>
      'tasmee-dl-${m.id}-${m.version}-${f.name}';

  static (ModelManifest, ModelFileSpec)? _decode(Task task) {
    try {
      final json = jsonDecode(task.metaData) as Map<String, dynamic>;
      final m = ModelManifest.fromJson(json['m'] as Map<String, dynamic>);
      final f = m.files.firstWhere((f) => f.name == json['f']);
      return (m, f);
    } catch (_) {
      return null;
    }
  }

  /// The model being downloaded (running, paused or failed), or null.
  ModelManifest? get active {
    for (final r in _downloads.tasks.value.values) {
      if (r.group != kGroup) continue;
      final d = _decode(r.task);
      if (d != null) return d.$1;
    }
    return null;
  }

  /// Ids of this model's tasks the system knows of.
  Iterable<String> get taskIds => _downloads.tasks.value.values
      .where((r) => r.group == kGroup)
      .map((r) => r.taskId);

  /// Downloads [manifest] in the background and completes once it is
  /// installed (at once if it already is). Calling it again while it runs
  /// joins the same download; [cancel] cancels its tasks.
  Future<InstalledModel> download(
    ModelManifest manifest, {
    void Function(ModelDownloadProgress progress)? onProgress,
    ModelDownloadCancel? cancel,
  }) async {
    final store = await modelStore();
    final already = await store.installedFor(manifest);
    if (already != null) return already;
    final dir = store.directoryFor(manifest);
    await dir.create(recursive: true);

    final key = _key(manifest);
    final waiter = _waiters.putIfAbsent(key, Completer<InstalledModel>.new);
    // Failures reach the await below; never reported as unhandled.
    waiter.future.ignore();
    final sub = _progress.stream
        .where((e) => e.$1 == key)
        .listen((e) => onProgress?.call(e.$2));
    cancel?.onCancel(() => unawaited(this.cancel()));
    try {
      var missing = 0;
      for (final f in manifest.files) {
        if (await ModelDownloader.matches(File(p.join(dir.path, f.name)), f)) {
          continue;
        }
        missing++;
        await _enqueue(manifest, f);
      }
      if (missing == 0) await _finish(manifest);
      _emit(manifest);
      return await waiter.future;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _enqueue(ModelManifest m, ModelFileSpec f) async {
    final id = taskIdFor(m, f);
    final record = _downloads.tasks.value[id];
    if (record != null) {
      switch (record.status) {
        case TaskStatus.paused:
          await _downloads.resume(id);
          return;
        case TaskStatus.failed || TaskStatus.notFound || TaskStatus.canceled:
          await _downloads.forget(id);
        default:
          if (await _downloads.taskForId(id) != null) return;
          await _downloads.forget(id);
      }
    } else if (await _downloads.taskForId(id) != null) {
      return;
    }
    await _downloads.enqueue(
      DownloadTask(
        taskId: id,
        url: f.url.toString(),
        filename: '${m.id}-${m.version}-${f.name}',
        directory: folder,
        baseDirectory: BaseDirectory.applicationSupport,
        group: kGroup,
        updates: Updates.statusAndProgress,
        allowPause: true,
        retries: 3,
        displayName: displayName,
        metaData: jsonEncode({'m': m.toJson(), 'f': f.name}),
        transferHints: {TransferHint.userInitiated, TransferHint.largeFile},
      ),
    );
  }

  Future<void> pause() async {
    for (final id in taskIds.toList()) {
      await _downloads.pause(id);
    }
  }

  Future<void> resume() async {
    for (final id in taskIds.toList()) {
      await _downloads.resume(id);
    }
  }

  /// Starts again a download that failed or stopped.
  Future<void> retry() async {
    final m = active;
    if (m != null) unawaited(download(m).then((_) {}, onError: (_) {}));
  }

  /// Cancels the download; files already checked stay for the next one.
  Future<void> cancel() async {
    final m = active;
    await _downloads.cancel(taskIds.toList());
    if (m != null) _fail(m, const ModelDownloadCancelled());
  }

  void _emit(ModelManifest m, [String file = '']) {
    var received = 0.0;
    for (final f in m.files) {
      received += f.bytes * (_fractions[taskIdFor(m, f)] ?? 0);
    }
    _progress.add((
      _key(m),
      ModelDownloadProgress(
        receivedBytes: received.round(),
        totalBytes: m.totalBytes,
        file: file,
      ),
    ));
  }

  void _fail(ModelManifest m, Object error) {
    final w = _waiters.remove(_key(m));
    if (w != null && !w.isCompleted) w.completeError(error);
  }

  @override
  Future<void> onUpdate(TaskUpdate update) async {
    final task = update.task;
    if (task is! DownloadTask) return;
    final d = _decode(task);
    if (d == null) return;
    final (m, f) = d;
    switch (update) {
      case TaskProgressUpdate(:final progress):
        if (progress < 0) return;
        _fractions[task.taskId] = progress.clamp(0, .99);
        _emit(m, f.name);
      case TaskStatusUpdate(:final status, :final exception):
        switch (status) {
          case TaskStatus.complete:
            await _place(task);
          case TaskStatus.failed || TaskStatus.notFound:
            _fail(
              m,
              ModelDownloadException(exception?.description ?? status.name),
            );
          case TaskStatus.canceled:
            _fractions.remove(task.taskId);
            _fail(m, const ModelDownloadCancelled());
          default:
            break;
        }
    }
  }

  @override
  Future<void> onFinishedWhileAway(DownloadTask task) => _place(task);

  /// Checks a finished file against the manifest and moves it into the
  /// model's folder; installs the model when it was the last one.
  Future<void> _place(DownloadTask task) async {
    final d = _decode(task);
    if (d == null || !_placing.add(task.taskId)) return;
    final (m, f) = d;
    try {
      final support = await _supportDir();
      final tmp = File(p.join(support.path, folder, task.filename));
      final store = await modelStore();
      final dir = store.directoryFor(m);
      await dir.create(recursive: true);
      final target = File(p.join(dir.path, f.name));
      if (!await ModelDownloader.matches(target, f)) {
        if (!await ModelDownloader.matches(tmp, f)) {
          if (await tmp.exists()) await tmp.delete();
          await _downloads.forget(task.taskId);
          _fractions.remove(task.taskId);
          _fail(m, ModelChecksumMismatch(f.name));
          return;
        }
        try {
          await tmp.rename(target.path);
        } on FileSystemException {
          await tmp.copy(target.path);
          await tmp.delete();
        }
      }
      _fractions[task.taskId] = 1;
      await _downloads.forget(task.taskId);
      _emit(m, f.name);
      for (final other in m.files) {
        final file = File(p.join(dir.path, other.name));
        if (!await file.exists() || await file.length() != other.bytes) {
          return;
        }
      }
      await _finish(m);
    } catch (e) {
      _fail(m, e);
    } finally {
      _placing.remove(task.taskId);
    }
  }

  Future<void> _finish(ModelManifest m) async {
    final store = await modelStore();
    final installed =
        await store.installedFor(m) ?? await store.markInstalled(m);
    for (final id in retiredRecitationModelIds) {
      if (id != m.id) await store.delete(id);
    }
    for (final f in m.files) {
      _fractions.remove(taskIdFor(m, f));
    }
    installs.value++;
    final w = _waiters.remove(_key(m));
    if (w != null && !w.isCompleted) w.complete(installed);
  }
}

/// The app's one [BackgroundModelDownload].
final backgroundModelDownloadProvider = Provider<BackgroundModelDownload>(
  (ref) => BackgroundModelDownload(
    downloads: ref.watch(backgroundDownloadsProvider),
    modelStore: ModelStore.inAppSupport,
  ),
);
