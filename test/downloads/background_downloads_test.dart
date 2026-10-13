import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/downloads/background_downloads.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/audio/background_recitations.dart';
import 'package:tibyan/features/audio/recitation.dart';
import 'package:tibyan/features/mushaf/presentation/background_downloads_list.dart';
import 'package:tibyan/features/tasmee/data/background_model_download.dart';
import 'package:tibyan/features/tasmee/data/model_downloader.dart';
import 'package:tibyan/features/tasmee/data/model_manifest.dart';
import 'package:tibyan/features/tasmee/data/model_store.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The system's downloader, in memory: it records what is queued and lets
/// the test send the updates the system would.
class FakeDownloader implements FileDownloader {
  final enqueued = <DownloadTask>[];
  final canceled = <String>[];
  final paused = <String>[];
  final resumed = <String>[];
  final _updates = StreamController<TaskUpdate>();
  final db = FakeDatabase();

  void send(TaskUpdate u) => _updates.add(u);

  @override
  Stream<TaskUpdate> get updates => _updates.stream;

  @override
  Database get database => db;

  @override
  Future<bool> enqueue(Task task) async {
    enqueued.add(task as DownloadTask);
    return true;
  }

  @override
  Future<Task?> taskForId(String taskId) async {
    for (final t in enqueued) {
      if (t.taskId == taskId && !canceled.contains(taskId)) return t;
    }
    return null;
  }

  @override
  Future<List<(String, String)>> configure({
    dynamic globalConfig,
    dynamic androidConfig,
    dynamic iOSConfig,
    dynamic desktopConfig,
  }) async => [];

  @override
  Future<void> start({
    bool doTrackTasks = true,
    bool markDownloadedComplete = true,
    bool doRescheduleKilledTasks = true,
    bool autoCleanDatabase = false,
  }) async {}

  @override
  FileDownloader registerCallbacks({
    String group = 'default',
    TaskStatusCallback? taskStatusCallback,
    TaskProgressCallback? taskProgressCallback,
    TaskNotificationTapCallback? taskNotificationTapCallback,
  }) => this;

  @override
  Future<bool> pause(DownloadTask task) async {
    paused.add(task.taskId);
    return true;
  }

  @override
  Future<bool> resume(DownloadTask task) async {
    resumed.add(task.taskId);
    return true;
  }

  @override
  Future<bool> cancelTasksWithIds(Iterable<String> taskIds) async {
    canceled.addAll(taskIds);
    return true;
  }

  @override
  FileDownloader configureNotificationForGroup(
    String group, {
    TaskNotification? running,
    TaskNotification? complete,
    TaskNotification? error,
    TaskNotification? paused,
    TaskNotification? canceled,
    TaskNotification? waitingToRetry,
    bool progressBar = false,
    bool tapOpensFile = false,
    String groupNotificationId = '',
  }) => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatabase implements Database {
  @override
  Future<List<TaskRecord>> allRecords({String? group}) async => [];

  @override
  Future<TaskRecord?> recordForId(String taskId) async => null;

  @override
  Future<void> deleteRecordWithId(String taskId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _bytes = utf8.encode('the model file');

ModelManifest _manifest(String sha) => ModelManifest.fromJson({
  'id': recitationModelId,
  'version': '7',
  'license': 'CC-BY-4.0',
  'engine': 'sherpa-onnx-nemo-ctc',
  'files': [
    {
      'name': 'tokens.txt',
      'url': 'https://example.org/tokens.txt',
      'sha256': sha,
      'bytes': _bytes.length,
    },
  ],
});

const _reciter = ReciterRow(
  id: 7,
  nameAr: 'المنشاوي',
  nameEn: 'Minshawi',
  style: 'murattal',
  folderUrl: 'https://host/minshawi/',
  sourceId: 1,
  riwaya: 'hafs',
);

/// Waits (on real file work) until [n] tasks are queued.
Future<void> _queued(FakeDownloader fake, [int n = 1]) async {
  for (var i = 0; i < 200 && fake.enqueued.length < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory tmp;
  late FakeDownloader fake;
  late BackgroundDownloads downloads;
  late BackgroundModelDownload model;
  late BackgroundRecitations recitations;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bg_downloads');
    fake = FakeDownloader();
    downloads = BackgroundDownloads(downloader: fake);
    model = BackgroundModelDownload(
      downloads: downloads,
      modelStore: () async => ModelStore(Directory(p.join(tmp.path, 'm'))),
      supportDir: () async => tmp,
    );
    recitations = BackgroundRecitations(
      downloads: downloads,
      files: AudioFiles(tmp),
      supportDir: () async => tmp,
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'the model is enqueued as a background task, checked, installed',
    () async {
      final m = _manifest(sha256.convert(_bytes).toString());
      final done = model.download(m);
      await _queued(fake);

      expect(fake.enqueued, hasLength(1));
      final task = fake.enqueued.single;
      expect(task.group, BackgroundModelDownload.kGroup);
      expect(task.url, 'https://example.org/tokens.txt');
      expect(task.baseDirectory, BaseDirectory.applicationSupport);
      expect(downloads.tasks.value.keys, [task.taskId]);
      expect(model.active?.version, '7');

      // The system finishes it while the app is away from the sheet.
      File(p.join(tmp.path, task.directory, task.filename))
        ..createSync(recursive: true)
        ..writeAsBytesSync(_bytes);
      await model.onUpdate(TaskStatusUpdate(task, TaskStatus.complete));

      final installed = await done;
      expect(installed.manifest.version, '7');
      expect(downloads.tasks.value, isEmpty);
      expect(model.installs.value, 1);
    },
  );

  test('a model file that does not match its checksum is refused', () async {
    final m = _manifest('0' * 64);
    final done = model.download(m);
    await _queued(fake);
    final task = fake.enqueued.single;
    File(p.join(tmp.path, task.directory, task.filename))
      ..createSync(recursive: true)
      ..writeAsBytesSync(_bytes);
    await model.onUpdate(TaskStatusUpdate(task, TaskStatus.complete));
    await expectLater(done, throwsA(isA<ModelChecksumMismatch>()));
  });

  test('cancelling the model cancels its tasks', () async {
    final cancel = ModelDownloadCancel();
    final done = model.download(
      _manifest(sha256.convert(_bytes).toString()),
      cancel: cancel,
    );
    await _queued(fake);
    cancel.cancel();
    await expectLater(done, throwsA(isA<ModelDownloadCancelled>()));
    expect(fake.canceled, [fake.enqueued.single.taskId]);
    expect(downloads.tasks.value, isEmpty);
  });

  test('a whole recitation is 114 background tasks, the other host on '
      'failure', () async {
    await recitations.enqueueAll(
      _reciter,
      urls: (s) => surahUrls(_reciter, s),
      displayName: 'المنشاوي',
    );
    expect(fake.enqueued, hasLength(114));
    expect(
      fake.enqueued.every((t) => t.group == BackgroundRecitations.kGroup),
      isTrue,
    );
    expect(recitations.queued(7, 1), isTrue);

    final first = fake.enqueued.first;
    await recitations.onUpdate(TaskStatusUpdate(first, TaskStatus.failed));
    expect(fake.enqueued.last.url, surahUrls(_reciter, 1).last.toString());

    // A finished surah lands where the player looks for it.
    final t = fake.enqueued.last;
    File(p.join(tmp.path, t.directory, t.filename))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await recitations.onUpdate(TaskStatusUpdate(t, TaskStatus.complete));
    expect(recitations.files.has(7, 1), isTrue);
    expect(recitations.queued(7, 1), isFalse);
  });

  test('a model download that failed is retried as a new task', () async {
    await downloads.start();
    final m = _manifest(sha256.convert(_bytes).toString());
    final first = model.download(m);
    await _queued(fake);
    final task = fake.enqueued.single;
    fake.send(TaskStatusUpdate(task, TaskStatus.failed));
    await expectLater(first, throwsA(isA<ModelDownloadException>()));
    expect(downloads.tasks.value[task.taskId]?.status, TaskStatus.failed);
    expect(model.active?.version, '7');

    await model.retry();
    await _queued(fake, 2);
    expect(fake.enqueued, hasLength(2));
    expect(fake.enqueued.last.taskId, task.taskId);
    expect(downloads.tasks.value[task.taskId]?.status, TaskStatus.enqueued);
  });

  test('a reciter is cancelled, and its failed surahs retried', () async {
    await downloads.start();
    await recitations.enqueueAll(
      _reciter,
      urls: (s) => surahUrls(_reciter, s).take(1).toList(),
      displayName: 'المنشاوي',
    );
    final first = fake.enqueued.first;
    fake.send(TaskStatusUpdate(first, TaskStatus.failed));
    await pumpEventQueue();
    expect(recitations.failed(7, 1), isTrue);

    await recitations.retryReciter(7);
    expect(fake.enqueued, hasLength(115));
    expect(recitations.queued(7, 1), isTrue);

    await recitations.cancelReciter(7);
    expect(fake.canceled, hasLength(114));
    expect(downloads.tasks.value, isEmpty);
  });

  test('a reciter is paused (waiting surahs held) and resumed', () async {
    await downloads.start();
    await recitations.enqueueAll(
      _reciter,
      urls: (s) => surahUrls(_reciter, s),
      displayName: 'المنشاوي',
    );
    final first = fake.enqueued.first;
    fake.send(TaskProgressUpdate(first, .5, 1000));
    await pumpEventQueue();

    await recitations.pauseReciter(7);
    await pumpEventQueue();
    expect(fake.paused, [first.taskId]);
    fake.send(TaskStatusUpdate(first, TaskStatus.paused));
    // The system reports the held ones cancelled: they stay listed.
    for (final t in fake.enqueued.skip(1)) {
      fake.send(TaskStatusUpdate(t, TaskStatus.canceled));
    }
    await pumpEventQueue();
    expect(recitations.paused(7), isTrue);
    expect(downloads.tasks.value, hasLength(114));

    await recitations.resumeReciter(7);
    expect(fake.resumed, [first.taskId]);
    expect(fake.enqueued, hasLength(114 + 113));
    expect(recitations.paused(7), isFalse);
  });

  testWidgets('the Downloads screen lists the model and the recitation', (
    tester,
  ) async {
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    await tester.runAsync(() async {
      unawaited(
        model
            .download(_manifest(sha256.convert(_bytes).toString()))
            .then((_) {}, onError: (_) {}),
      );
      while (fake.enqueued.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await recitations.enqueue(
        _reciter,
        1,
        urls: surahUrls(_reciter, 1),
        displayName: 'المنشاوي',
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backgroundDownloadsProvider.overrideWithValue(downloads),
          backgroundModelDownloadProvider.overrideWithValue(model),
          backgroundRecitationsProvider.overrideWithValue(recitations),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: ThemeModeId.light,
            uiFont: UiFont.changa,
          ),
          home: const Scaffold(body: BackgroundDownloadsList()),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('downloads-tasmee-model')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('downloads-reciter-7')), findsOneWidget);
    expect(find.text('المنشاوي'), findsOneWidget);

    // Cancel from the list.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('downloads-reciter-7')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    expect(find.byKey(const ValueKey('downloads-reciter-7')), findsNothing);
  });
}
