import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What one kind of download does with its tasks: the edition packs, the
/// recognition model, the recitations. Each kind has its own task group.
abstract interface class DownloadHandler {
  /// The task group of this kind (one per handler).
  String get group;

  /// The notification texts of this kind's tasks, or null for none.
  ({
    TaskNotification running,
    TaskNotification complete,
    TaskNotification error,
    TaskNotification paused,
    String groupNotificationId,
  })?
  get notifications;

  /// Every update of a task of [group].
  Future<void> onUpdate(TaskUpdate update);

  /// A task of [group] that finished while the app was closed.
  Future<void> onFinishedWhileAway(DownloadTask task);
}

/// The app's one background downloader (WorkManager / a user-initiated job
/// on Android, a background URLSession on iOS): downloads go on when the
/// reader leaves the screen or the app, with a notification while they run.
///
/// The system's update stream has a single listener, so every kind of
/// download goes through here: each registers a [DownloadHandler] for its
/// task group and gets that group's updates. [tasks] lists every task the
/// system knows of, for the Downloads screen.
class BackgroundDownloads {
  BackgroundDownloads({FileDownloader? downloader})
    : dl = downloader ?? FileDownloader();

  final FileDownloader dl;
  final _handlers = <String, DownloadHandler>{};
  StreamSubscription<TaskUpdate>? _sub;
  Future<void>? _started;
  final _held = <String>{};

  /// Called when the reader taps a download's notification (the app
  /// opens the Downloads screen; nothing is queued).
  void Function()? onNotificationTap;

  /// Every task not yet finished and installed, by task id.
  final tasks = ValueNotifier<Map<String, TaskRecord>>(const {});

  /// Adds a kind of download. Register before [start] so tasks that
  /// finished while the app was closed reach their handler.
  void register(DownloadHandler handler) {
    _handlers[handler.group] = handler;
    final n = handler.notifications;
    if (n != null) {
      dl.configureNotificationForGroup(
        handler.group,
        running: n.running,
        complete: n.complete,
        error: n.error,
        paused: n.paused,
        progressBar: true,
        groupNotificationId: n.groupNotificationId,
      );
      dl.registerCallbacks(
        group: handler.group,
        taskNotificationTapCallback: (_, _) => onNotificationTap?.call(),
      );
    }
  }

  /// Starts tracking: call once at startup (later calls wait for the
  /// first). Tasks that finished while the app was closed are handed over.
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    await dl.configure(
      androidConfig: [
        // Android before 14: a foreground service lifts the 9-minute limit.
        (Config.runInForeground, Config.always),
      ],
      // A whole mushaf of recitations is 114 tasks: a few at a time.
      globalConfig: [(Config.holdingQueue, (null, null, 3))],
    );
    _sub ??= dl.updates.listen(_onUpdate);
    await dl.start();
    final records = await dl.database.allRecords();
    tasks.value = {
      for (final r in records)
        if (_handlers.containsKey(r.group)) r.taskId: r,
    };
    for (final r in records) {
      final h = _handlers[r.group];
      if (h != null &&
          r.status == TaskStatus.complete &&
          r.task is DownloadTask) {
        await h.onFinishedWhileAway(r.task as DownloadTask);
      }
    }
  }

  /// Queues [task] (its handler takes over when it ends) and asks for
  /// notifications without holding the download on the answer.
  Future<bool> enqueue(DownloadTask task) async {
    final ok = await dl.enqueue(task);
    if (ok) {
      _set(TaskRecord(task, TaskStatus.enqueued, 0, -1));
      try {
        unawaited(
          dl.permissions
              .request(PermissionType.notifications)
              .then<void>((_) {}, onError: (_) {}),
        );
      } catch (_) {
        // No notifications: the download runs all the same.
      }
    }
    return ok;
  }

  Future<Task?> taskForId(String id) => dl.taskForId(id);

  Future<TaskRecord?> recordForId(String id) => dl.database.recordForId(id);

  Future<void> pause(String id) async {
    final t = await dl.taskForId(id);
    if (t is DownloadTask) await dl.pause(t);
  }

  /// Resumes a paused task; false when there is none to resume.
  Future<bool> resume(String id) async {
    if (_held.remove(id)) return false;
    final t = await dl.taskForId(id);
    if (t is DownloadTask) return dl.resume(t);
    return false;
  }

  /// Holds a task that has not started yet (the system cannot pause one
  /// still waiting in its queue): it leaves the queue and is listed as
  /// paused; [resume] reports false for it, and its handler queues it
  /// again.
  Future<void> hold(String id) async {
    final old = tasks.value[id];
    if (old == null) return;
    _held.add(id);
    await dl.cancelTasksWithIds([id]);
    _set(
      TaskRecord(
        old.task,
        TaskStatus.paused,
        old.progress,
        old.expectedFileSize,
      ),
    );
  }

  Future<void> cancel(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await dl.cancelTasksWithIds(ids);
    for (final id in ids) {
      await forget(id);
    }
  }

  /// Drops a task's record once its handler is done with it.
  Future<void> forget(String id) async {
    _held.remove(id);
    await dl.database.deleteRecordWithId(id);
    if (tasks.value.containsKey(id)) {
      tasks.value = {...tasks.value}..remove(id);
    }
  }

  void _set(TaskRecord r) => tasks.value = {...tasks.value, r.taskId: r};

  Future<void> _onUpdate(TaskUpdate update) async {
    final task = update.task;
    final h = _handlers[task.group];
    if (h == null) return;
    // A held task's cancellation: it stays listed as paused.
    if (_held.contains(task.taskId)) return;
    final old = tasks.value[task.taskId];
    switch (update) {
      case TaskProgressUpdate(:final progress, :final expectedFileSize):
        if (progress >= 0) {
          _set(
            TaskRecord(
              task,
              TaskStatus.running,
              progress,
              expectedFileSize > 0
                  ? expectedFileSize
                  : old?.expectedFileSize ?? -1,
            ),
          );
        }
      case TaskStatusUpdate(:final status, :final exception):
        if (status == TaskStatus.canceled) {
          if (old != null) tasks.value = {...tasks.value}..remove(task.taskId);
        } else {
          _set(
            TaskRecord(
              task,
              status,
              status == TaskStatus.complete ? 1 : old?.progress ?? 0,
              old?.expectedFileSize ?? -1,
              exception,
            ),
          );
        }
    }
    await h.onUpdate(update);
  }
}

/// The app's one [BackgroundDownloads].
final backgroundDownloadsProvider = Provider<BackgroundDownloads>(
  (ref) => BackgroundDownloads(),
);
