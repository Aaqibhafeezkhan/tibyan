import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/audio/timing_updates.dart';
import 'package:tibyan/features/mushaf/data/mushaf_repository.dart';
import 'package:tibyan/features/mushaf/data/page_pack.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/navigation.dart';

void main() {
  test('a verse link round-trips', () {
    final link = verseLink(2, 255);
    expect(link.toString(), 'tibyan://verse?s=2&a=255');
    expect(verseOfLink(link), (surah: 2, ayah: 255));
  });

  test('other links and bad numbers are not verses', () {
    expect(verseOfLink(Uri.parse('tibyan://khatma?page=3')), isNull);
    expect(verseOfLink(Uri.parse('https://verse?s=2&a=1')), isNull);
    expect(verseOfLink(Uri.parse('tibyan://verse?s=115&a=1')), isNull);
    expect(verseOfLink(Uri.parse('tibyan://verse?s=2')), isNull);
    expect(verseOfLink(null), isNull);
  });

  group('«آية اليوم» on the home screen opens its page', () {
    late ContentDatabase db;
    late Directory root;
    setUpAll(() {
      db = ContentDatabase(NativeDatabase(File('assets/db/content.db')));
      root = Directory.systemTemp.createTempSync('verse_link');
      // Both Madina editions' pages are on the device.
      for (final e in [MushafEdition.madina1441, MushafEdition.madina1405]) {
        final dir = Directory(p.join(root.path, 'packs', PagePackSpec.of(e).id))
          ..createSync(recursive: true);
        File(p.join(dir.path, '.installed')).writeAsStringSync('test');
      }
    });
    tearDownAll(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    Future<String> open(MushafEdition edition, Uri link) {
      final c = ProviderContainer(
        overrides: [
          contentDatabaseProvider.overrideWithValue(db),
          packRootProvider.overrideWithValue(root),
          chosenEditionProvider.overrideWithValue(edition),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(editionProvider), edition);
      final v = verseOfLink(link)!;
      return verseLinkLocation(c, v.surah, v.ayah);
    }

    for (final (s, a) in [(2, 255), (5, 83), (18, 1), (114, 6)]) {
      test('$s:$a in the 1441 and the 1405 edition', () async {
        // As verse_of_day.dart writes it for the widget.
        final link = Uri.parse('tibyan://verse?s=$s&a=$a&homeWidget=');
        final row = await MushafRepository(
          db,
          const NoTimingOverrides(),
        ).ayah(s, a);
        final at1441 = Uri.parse(await open(MushafEdition.madina1441, link));
        final at1405 = Uri.parse(await open(MushafEdition.madina1405, link));
        expect(at1441.queryParameters['page'], '${row.page}');
        expect(at1405.queryParameters['page'], '${row.page1405}');
        for (final u in [at1441, at1405]) {
          expect(u.path, '/mushaf');
          expect(
            (u.queryParameters['s'], u.queryParameters['a']),
            ('$s', '$a'),
          );
        }
      });
    }

    test('the two editions differ, so the edition is what decides', () async {
      final link = Uri.parse('tibyan://verse?s=5&a=83');
      final a = Uri.parse(await open(MushafEdition.madina1441, link));
      final b = Uri.parse(await open(MushafEdition.madina1405, link));
      expect(a.queryParameters['page'], isNot(b.queryParameters['page']));
    });
  });
}
