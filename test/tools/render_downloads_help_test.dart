import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/downloads/background_downloads.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/assistant/assistant_screen.dart';
import 'package:tibyan/features/assistant/help_topics.dart';
import 'package:tibyan/features/audio/background_recitations.dart';
import 'package:tibyan/features/audio/recitation.dart';
import 'package:tibyan/features/home/whats_new.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/downloads_center_screen.dart';
import 'package:tibyan/features/settings/report/report_screen.dart';
import 'package:tibyan/features/tasmee/data/background_model_download.dart';
import 'package:tibyan/features/tasmee/data/model_manifest.dart';
import 'package:tibyan/features/tasmee/data/model_store.dart';
import 'package:tibyan/l10n/app_localizations.dart';

import '../downloads/background_downloads_test.dart' show FakeDownloader;

/// Not a test: renders the Downloads screen (with the model and a reciter
/// downloading in the background), the help centre and one topic, and the
/// report form, in each interface style, light and night, into
/// `build/downloads_help/`. Runs only with RENDER_DOWNLOADS_HELP=1.
void main() {
  final run = Platform.environment['RENDER_DOWNLOADS_HELP'] == '1';
  const phone = Size(393, 852);

  testWidgets(
    'render downloads, help and report',
    (tester) async {
      await tester.runAsync(() async {
        final manifest = jsonDecode(
          await rootBundle.loadString('FontManifest.json'),
        ) as List<dynamic>;
        for (final f in manifest.cast<Map<String, dynamic>>()) {
          final loader = FontLoader(f['family'] as String);
          for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
            loader.addFont(
              rootBundle.load(Uri.decodeFull(a['asset'] as String)),
            );
          }
          await loader.load();
        }
      });
      final db = ContentDatabase(
        NativeDatabase(
          File('assets/db/content.db'),
          setup: (raw) => raw.execute('PRAGMA query_only = ON'),
        ),
      );
      final root = Directory.systemTemp.createTempSync('render_dh');
      final registry = (await tester.runAsync(
        () => ThemeRegistry.load(rootBundle),
      ))!;
      final out = Directory('build/downloads_help')
        ..createSync(recursive: true);
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => root.path,
      );

      // The model and Minshawi downloading in the background.
      final fake = FakeDownloader();
      final downloads = BackgroundDownloads(downloader: fake);
      final model = BackgroundModelDownload(
        downloads: downloads,
        modelStore: () async => ModelStore(Directory(p.join(root.path, 'm'))),
        supportDir: () async => root,
      );
      final recitations = BackgroundRecitations(
        downloads: downloads,
        files: AudioFiles(root),
        supportDir: () async => root,
      );
      const reciter = ReciterRow(
        id: 1,
        nameAr: 'محمد صديق المنشاوي',
        nameEn: 'Minshawi',
        style: 'murattal',
        folderUrl: 'https://host/minshawi/',
        sourceId: 1,
        riwaya: 'hafs',
      );
      await tester.runAsync(() async {
        await downloads.start();
        final bytes = utf8.encode('model');
        unawaited(
          model
              .download(
                ModelManifest.fromJson({
                  'id': recitationModelId,
                  'version': '7',
                  'license': 'CC-BY-4.0',
                  'engine': 'sherpa-onnx-nemo-ctc',
                  'files': [
                    {
                      'name': 'model.onnx',
                      'url': 'https://example.org/model.onnx',
                      'sha256': sha256.convert(bytes).toString(),
                      'bytes': 120000000,
                    },
                  ],
                }),
              )
              .then((_) {}, onError: (_) {}),
        );
        while (fake.enqueued.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        for (var s = 1; s <= 12; s++) {
          await recitations.enqueue(
            reciter,
            s,
            urls: surahUrls(reciter, s),
            displayName: reciter.nameAr,
          );
        }
        // Progress as the system would report it.
        final t = fake.enqueued;
        fake.send(TaskProgressUpdate(t[0], .42, 120000000));
        for (var i = 1; i <= 4; i++) {
          fake.send(TaskStatusUpdate(t[i], TaskStatus.running));
          fake.send(TaskProgressUpdate(t[i], .3 * i % 1, 9000000));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
        }
      }

      Future<void> shot(
        String name,
        Widget home, {
        required InterfaceStyle style,
        required bool night,
        Size size = phone,
        bool elderly = false,
      }) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        SharedPreferences.setMockInitialValues({
          'settings.interfaceStyle': style.name,
          'settings.onboardingDone': true,
          'settings.elderlyMode': elderly,
          whatsNewSeenKey: whatsNewId,
        });
        final sp = await SharedPreferences.getInstance();
        final user = UserDatabase(NativeDatabase.memory());
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                contentDatabaseProvider.overrideWithValue(db),
                userDatabaseProvider.overrideWithValue(user),
                themeRegistryProvider.overrideWithValue(registry),
                sharedPreferencesProvider.overrideWithValue(sp),
                packRootProvider.overrideWithValue(root),
                backgroundDownloadsProvider.overrideWithValue(downloads),
                backgroundModelDownloadProvider.overrideWithValue(model),
                backgroundRecitationsProvider.overrideWithValue(recitations),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: const Locale('ar'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: buildTheme(
                  style: registry.byId(registry.defaultStyleId),
                  mode: night ? ThemeModeId.night : ThemeModeId.light,
                  uiFont: UiFont.changa,
                  interfaceStyle: style,
                  elderly: elderly,
                ),
                builder: elderly
                    ? (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: const TextScaler.linear(1.25)),
                        child: child!,
                      )
                    : null,
                home: LookTheme(child: home),
              ),
            ),
          ),
        );
        await settle();
        final object =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await object.toImage(
            pixelRatio: size.width > 1000 ? 1 : 2,
          );
          final d = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return d!.buffer.asUint8List();
        });
        File('${out.path}/$name.png').writeAsBytesSync(bytes!);
        await tester.pumpWidget(const SizedBox());
      }

      final screens = <(String, Widget)>[
        ('downloads', const DownloadsCenterScreen()),
        ('assistant', const AssistantScreen()),
        ('help_topic', HelpTopicScreen(topic: helpTopics.first)),
        ('report', const ReportScreen()),
      ];
      for (final style in InterfaceStyle.values) {
        for (final night in [false, true]) {
          final tag = '${style.name}_${night ? 'night' : 'light'}';
          for (final (name, screen) in screens) {
            await shot(
              '${name}_$tag',
              screen,
              style: style,
              night: night,
              size: name == 'downloads' ? const Size(393, 2000) : phone,
            );
          }
        }
      }
      await shot(
        'downloads_laptop',
        const DownloadsCenterScreen(),
        style: defaultInterfaceStyle,
        night: false,
        size: const Size(1440, 1400),
      );
      await shot(
        'downloads_elderly',
        const DownloadsCenterScreen(),
        style: defaultInterfaceStyle,
        night: false,
        elderly: true,
        size: const Size(393, 2400),
      );
      await tester.pump(const Duration(minutes: 5));
      await tester.runAsync(db.close);
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
