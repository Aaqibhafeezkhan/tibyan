import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/features/audio/timing_updates.dart';
import 'package:tibyan/features/audio/word_timing_packs.dart';
import 'package:tibyan/features/mushaf/data/mushaf_repository.dart';

void main() {
  late ContentDatabase db;
  late Directory dir;
  var requests = 0;

  File packFile(int reciter) =>
      File(p.join('data', 'word_timing_packs', wordTimingSpecs[reciter]!.file));

  /// The mirror, serving the packs tools/build_lean_content.py wrote.
  MockClient server({bool damaged = false}) => MockClient((req) async {
    requests++;
    expect(req.url.toString(), startsWith(wordTimingBaseUrl));
    final name = req.url.pathSegments.last;
    final f = File(p.join('data', 'word_timing_packs', name));
    if (!f.existsSync()) return http.Response('', 404);
    final bytes = f.readAsBytesSync();
    if (damaged) bytes[100] ^= 0xff;
    return http.Response.bytes(bytes, 200);
  });

  setUpAll(() {
    db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
  });
  tearDownAll(() => db.close());
  setUp(() {
    dir = Directory.systemTemp.createTempSync('word-timing');
    requests = 0;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('content.db keeps the words only of reciters whose timings are not '
      'published; the rest are in packs', () async {
    final rows = await db
        .customSelect('SELECT DISTINCT reciter FROM word_timing')
        .get();
    final inDb = {for (final r in rows) r.read<int>('reciter')};
    expect(inDb, {15, 16});
    expect(wordTimingSpecs.keys.toSet(), {1, 2, 3, 4, 10, 11, 12, 13, 14});
    for (final MapEntry(:key, :value) in wordTimingSpecs.entries) {
      final bytes = packFile(key).readAsBytesSync();
      expect(bytes.length, value.bytes);
      final pack = TimingPack.decode(bytes);
      expect(pack.reciterId, key);
      expect(pack.wordRows(2), isNotEmpty);
    }
  });

  test('without its pack a reciter plays with verses only; the pack is '
      'fetched, verified, and then followed', () async {
    final words = WordTimingPacks(dir, client: server());
    final repo = MushafRepository(db, const NoTimingOverrides(), words);
    expect(await repo.timings(12, 1), isNotEmpty);
    expect(await repo.wordTimings(12, 1), isEmpty);

    final fetched = repo.fetchWordTimings(12, 1);
    expect(fetched, isNotNull);
    expect(await fetched, isNotEmpty);
    expect(words.has(12), isTrue);
    expect(await repo.wordTimings(12, 1), isNotEmpty);
    // Here now: nothing more to fetch, even from a fresh start.
    expect(repo.fetchWordTimings(12, 1), isNull);
    final again = WordTimingPacks(dir, client: server());
    expect(await again.pack(12), isNotNull);
    expect(requests, 1);
  });

  test('a damaged download is refused; offline, nothing changes', () async {
    final damaged = WordTimingPacks(dir, client: server(damaged: true));
    expect(await damaged.ensure(1), isFalse);
    expect(damaged.has(1), isFalse);

    final offline = WordTimingPacks(
      dir,
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    expect(await offline.ensure(1), isFalse);
    final repo = MushafRepository(db, const NoTimingOverrides(), offline);
    expect(await repo.fetchWordTimings(1, 2), isEmpty);
    expect(await repo.timings(1, 2), isNotEmpty, reason: 'verses still play');
  });

  test('a pack changed on disk is not used', () async {
    final words = WordTimingPacks(dir, client: server());
    expect(await words.ensure(3), isTrue);
    final f = words.file(3);
    final bytes = f.readAsBytesSync()..[50] ^= 0xff;
    f.writeAsBytesSync(bytes);
    expect(await WordTimingPacks(dir).pack(3), isNull);
    expect(f.existsSync(), isFalse, reason: 'fetched again next time');
  });

  test('reciters whose words stay in content.db need no pack', () async {
    final words = WordTimingPacks(dir, client: server());
    final repo = MushafRepository(db, const NoTimingOverrides(), words);
    expect(repo.fetchWordTimings(15, 2), isNull);
    expect(await repo.wordTimings(15, 2), isNotEmpty);
    expect(await words.ensure(15), isFalse);
    expect(requests, 0);
  });

  test('downloaded audio brings its words after an update', () async {
    final words = WordTimingPacks(dir, client: server());
    await words.ensureAll([1, 15, 10]);
    expect(words.has(1), isTrue);
    expect(words.has(10), isTrue);
    expect(requests, 2);
  });
}
