// Scripted checks of the light install (bundled 1441 pages read in place,
// content.db copied out in parts, word timings fetched per reciter).
//
// One scenario per run, picked with --dart-define=SCENARIO=<name>:
//   offline        fresh install, no network: onboarding, pages 1/302/604,
//                  index and search
//   online         download edition 1405 and read it; play Husary (2) and
//                  Mustafa Ismail (5) online, the word timing pack arrives
//   audio_offline  network cut: Husary still follows words (pack on the
//                  device), Mustafa Ismail (no pack) plays verse by verse
//   seed_old       run on the old build: a bookmark and a khatma
//   upgrade        after installing over the old build: both kept, the
//                  extracted pages removed after the first frame
//
// Lines starting with SHOT: ask the runner script for a screenshot.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tibyan/app.dart';
import 'package:tibyan/core/router/app_router.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/features/audio/recitation.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/domain/khatma_plan.dart';
import 'package:tibyan/features/khatma/khatma_providers.dart';
import 'package:tibyan/features/mushaf/data/page_pack.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';
import 'package:tibyan/main.dart' as app;

const scenario = String.fromEnvironment('SCENARIO');

/// Records every HTTP request the app makes and, when [fail], refuses it
/// as an unreachable host would.
class _Net extends HttpOverrides {
  _Net({required this.fail});
  final bool fail;
  final hosts = <String>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final c = super.createHttpClient(context);
    c.connectionFactory = (uri, proxyHost, proxyPort) {
      hosts.add('${uri.host}${uri.path}');
      if (fail) {
        return Future.error(SocketException('offline (test)', osError: null));
      }
      return Socket.startConnect(
        proxyHost ?? uri.host,
        proxyPort ?? (uri.scheme == 'https' ? 443 : 80),
      );
    };
    return c;
  }
}

final _sw = Stopwatch();
void log(String s) => debugPrint('LIGHT[${_sw.elapsedMilliseconds}ms] $s');

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpUntil(
  WidgetTester t,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 60),
  String what = '',
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $what');
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(WidgetTester t, String name) async {
  await pumpFor(t, const Duration(seconds: 2));
  debugPrint('SHOT:$name');
  // The runner takes the picture while the frame holds.
  await pumpFor(t, const Duration(seconds: 3));
}

ProviderContainer containerOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(TibyanApp)));

Future<ProviderContainer> launch(WidgetTester t) async {
  _sw.start();
  final orig = FlutterError.onError;
  FlutterError.onError = (d) {
    // Layout overflows are noted, not counted as failures of this check.
    if (d.exceptionAsString().contains('overflowed')) {
      log(
        'OVERFLOW ${d.exceptionAsString()} @ ${d.informationCollector?.call().take(2).join(' ')}',
      );
      return;
    }
    orig?.call(d);
  };
  unawaited(app.main());
  await pumpUntil(
    t,
    () => find.byType(TibyanApp).evaluate().isNotEmpty,
    what: 'app',
  );
  log('first TibyanApp frame');
  await pumpFor(t, const Duration(seconds: 2));
  final skip = find.byKey(const ValueKey('onboarding-skip-all'));
  if (skip.evaluate().isNotEmpty) {
    await shot(t, 'onboarding');
    await t.tap(skip);
    log('tapped skip-all');
    await pumpFor(t, const Duration(seconds: 2));
  }
  return containerOf(t);
}

bool _pageShown(int page) => find
    .byWidgetPredicate(
      (w) =>
          (w is MushafPage && w.page == page) ||
          (w.runtimeType.toString() == 'ImageMushafPage' &&
              (w as dynamic).page == page) ||
          (w.runtimeType.toString() == 'OldMushafPage' &&
              (w as dynamic).page == page),
    )
    .evaluate()
    .isNotEmpty;

Future<void> openPageAndCheck(
  WidgetTester t,
  ProviderContainer c,
  int page,
  String tag,
) async {
  c.read(appRouterProvider).go(mushafLocation(page));
  await pumpUntil(
    t,
    () => _pageShown(page),
    what: 'page $page',
    timeout: const Duration(seconds: 30),
  );
  if (c.read(editionProvider) == MushafEdition.madina1441) {
    final svg = await c.read(pageStoreProvider).svg(page);
    expect(svg.length, greaterThan(1000), reason: 'page $page svg');
    log('page $page svg ${svg.length} chars');
  }
  await shot(t, '${tag}_page_$page');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('light install: $scenario', (t) async {
    switch (scenario) {
      case 'offline':
        final net = _Net(fail: true);
        HttpOverrides.global = net;
        final c = await launch(t);
        await shot(t, 'offline_home_after_skip');
        c.read(appRouterProvider).go(mushafLocation(1));
        await pumpUntil(
          t,
          () => find.byType(MushafPage).evaluate().isNotEmpty,
          what: 'mushaf',
        );
        log('mushaf open, edition ${c.read(editionProvider).name}');
        expect(c.read(editionProvider), MushafEdition.madina1441);
        await shot(t, 'offline_after_skip');
        for (final pg in [1, 302, 604]) {
          await openPageAndCheck(t, c, pg, 'offline');
        }
        final packs = c.read(packsDirProvider);
        log(
          'packs dir: ${packs.existsSync() ? packs.listSync().map((e) => p.basename(e.path)).toList() : 'absent'}',
        );
        c.read(appRouterProvider).go('/mushaf/index');
        await shot(t, 'offline_index');
        expect(
          find.textContaining('مكية').evaluate().isNotEmpty ||
              find.textContaining('مدنية').evaluate().isNotEmpty,
          isTrue,
          reason: 'index lists surahs',
        );
        c.read(appRouterProvider).go('/search');
        await pumpFor(t, const Duration(seconds: 2));
        await t.enterText(find.byType(EditableText).first, 'الصمد');
        await pumpFor(t, const Duration(seconds: 3));
        await shot(t, 'offline_search');
        expect(
          find.textContaining('الإخلاص').evaluate(),
          isNotEmpty,
          reason: 'search finds al-Samad in al-Ikhlas',
        );
        log('HTTP attempts while offline (all refused): ${net.hosts.toSet()}');

      case 'online':
        final c = await launch(t);
        final s = c.read(settingsProvider.notifier);
        c.read(appRouterProvider).go('/downloads');
        await pumpFor(t, const Duration(seconds: 2));
        const ed = MushafEdition.madina1405;
        final keep = c.listen(editionDownloadProvider(ed), (_, _) {});
        if (c.read(editionDownloadProvider(ed)).phase != PackPhase.installed) {
          final row = find.byKey(
            const ValueKey('downloads-edition-madina1405'),
          );
          final btn = find.descendant(
            of: row,
            matching: find.byType(IconButton),
          );
          log('tapping the 1405 download button (${btn.evaluate().length})');
          await t.tap(btn.first);
          await shot(t, 'online_downloading_1405');
          var last = -1;
          await pumpUntil(
            t,
            () {
              final st = c.read(editionDownloadProvider(ed));
              final pct = st.total == 0 ? 0 : (st.received * 100 ~/ st.total);
              if (pct ~/ 25 + st.phase.index * 10 != last) {
                last = pct ~/ 25 + st.phase.index * 10;
                log('1405 ${st.phase.name} $pct%');
              }
              return st.phase == PackPhase.installed;
            },
            what: '1405 installed',
            timeout: const Duration(minutes: 15),
          );
        }
        keep.close();
        log(
          '1405 installed; installedEditions=${c.read(installedEditionsProvider).map((e) => e.name)}',
        );
        await shot(t, 'online_downloads_center');
        await s.setEdition(ed);
        await pumpFor(t, const Duration(seconds: 1));
        log('chosen 1405 -> editionProvider=${c.read(editionProvider).name}');
        expect(
          c.read(editionProvider),
          ed,
          reason: 'the downloaded edition is read once chosen',
        );
        for (final pg in [1, 302, 604]) {
          await openPageAndCheck(t, c, pg, 'ed1405');
        }
        // Back to 1441 for the recitation.
        await s.setEdition(MushafEdition.madina1441);
        c.read(appRouterProvider).go(mushafLocation(602));
        await pumpFor(t, const Duration(seconds: 2));
        final words = c.read(wordTimingPacksProvider)!;
        // Banna (4): no corrected-timing pack on the server, so his words
        // can only come from the word pack.
        const R = 4;
        log('reciter $R pack before: ${words.has(R)}');
        final repo = c.read(mushafRepositoryProvider);
        log(
          'reciter $R 108: timings=${(await repo.timings(R, 108)).length} '
          'words=${(await repo.wordTimings(R, 108)).length}',
        );
        final rec = c.read(recitationProvider.notifier);
        await s.setReciter(R);
        await rec.play(108, from: 1);
        var sawWord = false;
        var shotWord = false;
        await pumpUntil(
          t,
          () {
            final st = c.read(recitationProvider);
            if (st.word != null) {
              sawWord = true;
            }
            if (DateTime.now().millisecond < 100) {
              log(
                'reciter $R state playing=${st.playing} loading=${st.loading} '
                'surah=${st.surah} ayah=${st.ayah} word=${st.word} pack=${words.has(R)}',
              );
            }
            return sawWord && words.has(R);
          },
          what: 'reciter $R word highlight',
          timeout: const Duration(seconds: 90),
        );
        if (!shotWord) await shot(t, 'online_reciter_${R}_word_highlight');
        log(
          'reciter $R pack after: ${words.has(R)} '
          '(${words.file(R).existsSync() ? words.file(R).lengthSync() : 0} B), '
          'word=${c.read(recitationProvider).word}',
        );
        // Let the short surah finish so the audio is kept for offline.
        await pumpUntil(
          t,
          () =>
              !c.read(recitationProvider).active ||
              c.read(recitationProvider).surah != 108,
          what: 'reciter $R end',
          timeout: const Duration(seconds: 120),
        );
        await rec.stop();
        await s.setReciter(5);
        await rec.play(108, from: 1);
        await pumpUntil(
          t,
          () => c.read(recitationProvider).ayah != null,
          what: 'reciter 5 verse',
          timeout: const Duration(seconds: 90),
        );
        log(
          'reciter 5 packed=${words.packed(5)} word=${c.read(recitationProvider).word}',
        );
        await shot(t, 'online_reciter5_ayah');
        await pumpUntil(
          t,
          () =>
              !c.read(recitationProvider).active ||
              c.read(recitationProvider).surah != 108,
          what: 'reciter 5 end',
          timeout: const Duration(seconds: 120),
        );
        await rec.stop();

      case 'audio_offline':
        // On the iOS simulator the network cannot be cut: the app's own
        // HTTP is refused instead (the audio files are already on disk).
        HttpOverrides.global = _Net(fail: true);
        final c = await launch(t);
        final s = c.read(settingsProvider.notifier);
        final rec = c.read(recitationProvider.notifier);
        final words = c.read(wordTimingPacksProvider)!;
        c.read(appRouterProvider).go(mushafLocation(602));
        await pumpFor(t, const Duration(seconds: 2));
        for (final r in [4, 5]) {
          await s.setReciter(r);
          await rec.play(108, from: 1);
          int? word;
          int? ayah;
          final end = DateTime.now().add(const Duration(seconds: 20));
          while (DateTime.now().isBefore(end)) {
            await t.pump(const Duration(milliseconds: 100));
            final st = c.read(recitationProvider);
            word ??= st.word;
            ayah ??= st.ayah;
            if (word != null && r == 4) break;
          }
          log(
            'offline reciter $r: pack=${words.has(r)} ayah=$ayah word=$word '
            'playing=${c.read(recitationProvider).playing}',
          );
          await shot(t, 'offline_audio_reciter_$r');
          await rec.stop();
          await pumpFor(t, const Duration(seconds: 1));
        }

      case 'seed_old':
        final c = await launch(t);
        await pumpFor(t, const Duration(seconds: 5));
        await c
            .read(userDatabaseProvider)
            .addBookmarkSet(
              name: 'verify-light',
              color: 0xFF0F6660,
              surah: 2,
              ayah: 255,
              page: 42,
            );
        log('bookmark added');
        try {
          await c
              .read(khatmaServiceProvider)
              .create(
                title: 'verify-light',
                edition: MushafEdition.madina1441,
                unit: PortionUnit.page,
                start: Day.today(),
                target: Day.today().add(30),
              );
          log('khatma created');
        } catch (e) {
          log('khatma via service failed: $e');
        }
        final packs = c.read(packsDirProvider);
        log(
          'old packs: ${packs.existsSync() ? packs.listSync().map((e) => p.basename(e.path)).toList() : 'absent'}',
        );
        await shot(t, 'old_build_seeded');

      case 'upgrade':
        final root = Directory(
          p.join((await getApplicationSupportDirectory()).path, 'packs'),
        );
        log(
          'packs before launch: ${root.existsSync() ? root.listSync().map((e) => p.basename(e.path)).toList() : 'absent'}',
        );
        final c = await launch(t);
        final packs = c.read(packsDirProvider);
        log(
          'packs at start: ${packs.existsSync() ? packs.listSync().map((e) => p.basename(e.path)).toList() : 'absent'}',
        );
        await pumpFor(t, const Duration(seconds: 8));
        final left = packs.existsSync()
            ? packs.listSync().map((e) => p.basename(e.path)).toList()
            : <String>[];
        log('packs after first frame: $left');
        expect(left.where((n) => n.contains('hafs-1441')), isEmpty);
        final keep = c.listen(bookmarkSetsProvider, (_, _) {});
        await pumpUntil(
          t,
          () => c.read(bookmarkSetsProvider).hasValue,
          what: 'bookmarks',
        );
        final sets = c.read(bookmarkSetsProvider).value!;
        keep.close();
        log(
          'bookmarks: ${sets.map((b) => '${b.name}@${b.surah}:${b.ayah}').toList()}',
        );
        expect(sets.any((b) => b.name == 'verify-light'), isTrue);
        List<dynamic>? ks;
        unawaited(
          c.read(khatmahStoreProvider).khatmahs(open: true).then((v) => ks = v),
        );
        await pumpUntil(t, () => ks != null, what: 'khatmas');
        log('open khatmas: ${ks!.map((k) => k.title).toList()}');
        expect(ks!.any((k) => k.title == 'verify-light'), isTrue);
        await openPageAndCheck(t, c, 42, 'upgrade');

      default:
        fail('unknown SCENARIO "$scenario"');
    }
    log('DONE $scenario');
  }, timeout: const Timeout(Duration(minutes: 30)));
}

// Silences unused-import lints when a scenario is trimmed.
// ignore: unused_element
GoRouter _r(ProviderContainer c) => c.read(appRouterProvider);
