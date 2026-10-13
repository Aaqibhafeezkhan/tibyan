import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/downloads/background_downloads.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/audio/background_recitations.dart';
import 'package:tibyan/features/audio/recitation.dart';
import 'package:tibyan/features/mushaf/presentation/downloads_center_screen.dart';
import 'package:tibyan/features/tasmee/data/background_model_download.dart';
import 'package:tibyan/features/tasmee/data/model_store.dart';

import '../tasmee/tasmee_test_env.dart';
import 'background_downloads_test.dart' show FakeDownloader;

const _reciter = ReciterRow(
  id: 7,
  nameAr: 'المنشاوي',
  nameEn: 'Minshawi',
  style: 'murattal',
  folderUrl: 'https://host/minshawi/',
  sourceId: 1,
  riwaya: 'hafs',
);

void main() {
  late TasmeeTestData data;
  setUpAll(() => data = TasmeeTestData.open());
  tearDownAll(() => data.close());

  testWidgets('opening the Downloads Center queues nothing, and leaving it '
      'keeps a running download going', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => data.root.path,
    );
    tester.view
      ..physicalSize = const Size(430, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeDownloader();
    final downloads = BackgroundDownloads(downloader: fake);
    final tmp = Directory.systemTemp.createTempSync('center');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final model = BackgroundModelDownload(
      downloads: downloads,
      modelStore: () async => ModelStore(Directory(p.join(tmp.path, 'm'))),
      supportDir: () async => tmp,
    );
    final recitations = BackgroundRecitations(
      downloads: downloads,
      files: AudioFiles(tmp),
      supportDir: () async => tmp,
    );
    await tester.runAsync(
      () => recitations.enqueue(
        _reciter,
        1,
        urls: surahUrls(_reciter, 1),
        displayName: 'المنشاوي',
      ),
    );
    expect(fake.enqueued, hasLength(1));

    final container = await tasmeeContainer(
      tester,
      data,
      overrides: [
        backgroundDownloadsProvider.overrideWithValue(downloads),
        backgroundModelDownloadProvider.overrideWithValue(model),
        backgroundRecitationsProvider.overrideWithValue(recitations),
      ],
    );
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      tasmeeApp(
        container,
        Navigator(
          key: nav,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox()),
          ),
        ),
        theme: tasmeeTheme(container),
      ),
    );
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const LookTheme(child: DownloadsCenterScreen()),
        ),
      ),
    );
    await settle(tester);

    // Opening it starts nothing new.
    expect(fake.enqueued, hasLength(1));
    expect(find.text('المصاحف'), findsOneWidget);
    expect(find.text('القراءات الصوتية'), findsOneWidget);
    expect(find.byKey(const ValueKey('downloads-reciter-7')), findsOneWidget);

    // Leaving it: the download goes on, and the reader is told so.
    nav.currentState!.pop();
    await settle(tester);
    expect(fake.canceled, isEmpty);
    expect(downloads.tasks.value.values.single.status, TaskStatus.enqueued);
    expect(find.text('يكمل التحميل في الخلفية'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
