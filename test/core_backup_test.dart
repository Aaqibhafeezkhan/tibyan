import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/backup/backup.dart';
import 'package:tibyan/core/db/user_database.dart';

UserDatabase _db() => UserDatabase(NativeDatabase.memory());

void main() {
  group('settings and outbox', settingsAndOutbox);
  late UserDatabase a;
  late UserDatabase b;
  setUp(() {
    a = _db();
    b = _db();
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<void> fill(UserDatabase db) async {
    await db.savePosition(
      edition: 'madina1441',
      view: 'page',
      surah: 2,
      ayah: 255,
      page: 42,
    );
    await db.setMark(MarkKind.hifz, name: 'حفظ', surah: 67, ayah: 1, page: 562);
    await db.addBookmarkSet(
      name: 'ورد',
      color: 0xFF2F6B4F,
      surah: 18,
      ayah: 10,
      page: 294,
    );
    await db
        .into(db.reflections)
        .insert(ReflectionsCompanion.insert(surah: 1, ayah: 2, body: 'تدبر'));
  }

  test('a backup restores on an empty device', () async {
    await fill(a);
    final text = await Backup(a).export();
    final r = await Backup(b).import(text);
    expect(r.added, greaterThanOrEqualTo(4));
    expect((await b.position())!.page, 42);
    final sets = await b.watchBookmarkSets().first;
    expect(sets.map((s) => s.name), containsAll(['حفظ', 'ورد']));
    final notes = await b.select(b.reflections).get();
    expect(notes.single.body, 'تدبر');
  });

  test('restoring twice adds nothing the second time', () async {
    await fill(a);
    final text = await Backup(a).export();
    await Backup(b).import(text);
    final again = await Backup(b).import(text);
    expect(again.added, 0);
    expect((await b.select(b.reflections).get()), hasLength(1));
    expect((await b.watchBookmarkSets().first), hasLength(2));
  });

  test(
    'a newer copy of a note replaces the older one, an older one does not',
    () async {
      await fill(a);
      final note = (await a.select(a.reflections).get()).single;
      // The device has an older edit of the same note.
      await Backup(b).import(await Backup(a).export());
      await (b.update(
        b.reflections,
      )..where((t) => t.uuid.equals(note.uuid))).write(
        ReflectionsCompanion(
          body: const Value('قديم'),
          updatedAt: Value(note.updatedAt.subtract(const Duration(days: 1))),
        ),
      );
      await Backup(b).import(await Backup(a).export());
      expect((await b.select(b.reflections).get()).single.body, 'تدبر');

      // The device's own newer edit stays.
      await (b.update(
        b.reflections,
      )..where((t) => t.uuid.equals(note.uuid))).write(
        ReflectionsCompanion(
          body: const Value('أحدث'),
          updatedAt: Value(note.updatedAt.add(const Duration(days: 1))),
        ),
      );
      await Backup(b).import(await Backup(a).export());
      expect((await b.select(b.reflections).get()).single.body, 'أحدث');
    },
  );

  test('files that are not backups are refused', () async {
    expect(Backup(b).import('hello'), throwsA(isA<BackupException>()));
    expect(
      Backup(b).import('{"app":"other","tables":{}}'),
      throwsA(isA<BackupException>()),
    );
    expect(
      Backup(b).import('{"app":"tibyan","format":99,"tables":{}}'),
      throwsA(isA<BackupException>()),
    );
  });
}

void settingsAndOutbox() {
  test('settings travel with the backup and come back on restore', () async {
    SharedPreferences.setMockInitialValues({
      'settings.style': 'seljuk',
      'settings.playbackSpeed': 1.25,
      'settings.underVerse': ['8', '9'],
      'search.history': ['x'], // not a setting: stays out
    });
    final prefs = await SharedPreferences.getInstance();
    final a = _db();
    final text = await Backup(a, prefs: prefs).export();
    await a.close();

    SharedPreferences.setMockInitialValues({'settings.style': 'zakhrafa'});
    final fresh = await SharedPreferences.getInstance();
    final b = _db();
    final r = await Backup(b, prefs: fresh).import(text);
    await b.close();
    expect(r.settings, 3);
    expect(fresh.getString('settings.style'), 'seljuk');
    expect(fresh.getDouble('settings.playbackSpeed'), 1.25);
    expect(fresh.getStringList('settings.underVerse'), ['8', '9']);
    expect(fresh.getStringList('search.history'), isNull);
  });

  test('the reader\'s choices outside settings.* travel too; the device\'s '
      'state does not', () async {
    SharedPreferences.setMockInitialValues({
      'tasmee.mode': 'hidden',
      'tasmee.toastSeconds': 5,
      'tasmee.vibration': false,
      'tasmee.firstUseSeen': true,
      'habits.streakNotes': false,
      'search.mode': 'meaning',
      'app.whatsNewSeen': 'v2',
      'window.bounds': ['0', '0', '800', '600'],
      'sync.lastPull': 123,
      'reports.queue': ['{"email":"a@b.co"}'],
      'tasmee.modelLatest': '{}',
      'khatma.wirdBannerDismissed': 'k1:2026-10-07',
    });
    final prefs = await SharedPreferences.getInstance();
    final a = _db();
    final text = await Backup(a, prefs: prefs).export();
    await a.close();
    expect(text, isNot(contains('a@b.co')));

    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    final b = _db();
    final r = await Backup(b, prefs: fresh).import(text);
    await b.close();
    expect(r.settings, 7);
    expect(fresh.getString('tasmee.mode'), 'hidden');
    expect(fresh.getInt('tasmee.toastSeconds'), 5);
    expect(fresh.getBool('tasmee.vibration'), isFalse);
    expect(fresh.getBool('tasmee.firstUseSeen'), isTrue);
    expect(fresh.getBool('habits.streakNotes'), isFalse);
    expect(fresh.getString('search.mode'), 'meaning');
    expect(fresh.getString('app.whatsNewSeen'), 'v2');
    for (final k in [
      'window.bounds',
      'sync.lastPull',
      'reports.queue',
      'tasmee.modelLatest',
      'khatma.wirdBannerDismissed',
    ]) {
      expect(fresh.containsKey(k), isFalse, reason: k);
    }
  });

  test('a file holding keys a backup does not carry restores only the '
      'carried ones', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    final b = _db();
    // As an older file (settings only) or an edited one may be.
    final r = await Backup(b, prefs: fresh).import(
      '{"app":"tibyan","format":1,"tables":{},'
      '"settings":{"settings.style":"seljuk","sync.lastPull":9}}',
    );
    await b.close();
    expect(r.settings, 1);
    expect(fresh.getString('settings.style'), 'seljuk');
    expect(fresh.containsKey('sync.lastPull'), isFalse);
  });

  test('a restored note is queued for sync like any other write', () async {
    final a = _db();
    final b = _db();
    await a
        .into(a.reflections)
        .insert(ReflectionsCompanion.insert(surah: 2, ayah: 3, body: 'x'));
    final uuid = (await a.select(a.reflections).get()).single.uuid;
    await Backup(b).import(await Backup(a).export());
    final queued = await b.select(b.outbox).get();
    expect(queued.single.entity, 'reflection');
    expect(queued.single.rowUuid, uuid);
    expect(queued.single.payload, contains('"body":"x"'));
    await a.close();
    await b.close();
  });
}
