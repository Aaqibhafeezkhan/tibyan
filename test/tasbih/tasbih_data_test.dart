import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tibyan/core/backup/backup.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/features/tasbih/data/tasbih_repository.dart';
import 'package:tibyan/features/tasbih/domain/dhikr.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late TasbihRepository repo;
  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    repo = TasbihRepository(db);
  });
  tearDown(() => db.close());

  test('the day key turns at local midnight', () {
    expect(tasbihDayKey(DateTime(2026, 10, 16, 23, 59)), '2026-10-16');
    expect(tasbihDayKey(DateTime(2026, 10, 17, 0, 0)), '2026-10-17');
  });

  test('counts add up per dhikr per day', () async {
    final day = DateTime(2026, 10, 16, 9);
    await repo.record('app:seen34', at: day);
    await repo.record('app:seen34', at: day);
    await repo.record('app:seen34', rounds: 1, at: day);
    await repo.record('app:seen33', count: 7, at: day);
    await repo.record('app:seen34', at: DateTime(2026, 10, 17, 0, 1));
    final log = await repo.watchLog().first;
    expect(log.keys, ['2026-10-17', '2026-10-16']);
    expect(log['2026-10-16']!['app:seen34'], (count: 3, rounds: 1));
    expect(log['2026-10-16']!['app:seen33'], (count: 7, rounds: 0));
    expect(await repo.dayCount('app:seen34', at: day), 3);
  });

  test('the log keeps thirty days', () async {
    final now = DateTime(2026, 10, 16, 12);
    for (var i = 0; i < 40; i++) {
      await repo.record('app:x', at: now.subtract(Duration(days: i)));
    }
    await repo.prune(now: now);
    final log = await repo.watchLog().first;
    expect(log.length, tasbihLogDays);
    expect(log.keys.last, tasbihDayKey(now.subtract(const Duration(days: 29))));
  });

  test('the reader adds, edits and deletes their own dhikr', () async {
    final d = await repo.add('  نص  ', reference: ' ', target: 100);
    expect(d.mine, isTrue);
    expect(d.text, 'نص');
    expect(d.reference, isNull);
    await repo.edit(d.uuid!, text: 'نص آخر', reference: 'مرجع', target: null);
    final edited = (await repo.mine()).single;
    expect(edited.text, 'نص آخر');
    expect(edited.reference, 'مرجع');
    expect(edited.target, isNull);
    await repo.remove(d.uuid!);
    expect(await repo.mine(), isEmpty);
  });

  test('a backup carries the misbaha tables and merges a day once', () async {
    await repo.add('ذكر', target: 33);
    await repo.record('app:seen34', count: 12, at: DateTime(2026, 10, 16));
    final text = await Backup(db).export();
    final tables = (jsonDecode(text) as Map)['tables'] as Map;
    expect(tables.keys, containsAll(['tasbih_dhikr', 'tasbih_day']));
    final other = UserDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await Backup(other).import(text);
    await Backup(other).import(text);
    final r = TasbihRepository(other);
    expect((await r.mine()).single.text, 'ذكر');
    final log = await r.watchLog().first;
    expect(log['2026-10-16']!['app:seen34']!.count, 12);
  });

  test('a version 6 database gains the misbaha tables', () async {
    final dir = Directory.systemTemp.createTempSync('tasbih_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/user.db');
    // A database as version 6 left it: everything but the new tables.
    final v7 = UserDatabase(NativeDatabase(file));
    await v7.customSelect('SELECT 1').get();
    await v7.close();
    final raw = sqlite3.open(file.path)
      ..execute('DROP TABLE tasbih_day')
      ..execute('DROP TABLE tasbih_dhikr')
      ..execute('PRAGMA user_version = 6');
    raw.close();
    final upgraded = UserDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final r = TasbihRepository(upgraded);
    await r.record('app:seen34');
    expect(await r.dayCount('app:seen34'), 1);
    final version = await upgraded.customSelect('PRAGMA user_version').get();
    expect(version.single.data.values.single, upgraded.schemaVersion);
  });

  test('the app adhkar file is read with its source and references', () {
    final text = File('assets/tasbih/adhkar.json').readAsStringSync();
    final parsed = parseAppAdhkar(text);
    expect(
      parsed.sources.map((s) => s.license),
      containsAll(['MIT', 'Apache-2.0']),
    );
    for (final s in parsed.sources) {
      expect(s.url, startsWith('https://github.com/'));
      expect(s.commit, hasLength(40));
    }
    expect(parsed.adhkar, isNotEmpty);
    for (final d in parsed.adhkar) {
      expect(d.key, startsWith('app:'));
      expect(d.mine, isFalse);
      expect(d.reference, isNotEmpty);
    }
  });
}
