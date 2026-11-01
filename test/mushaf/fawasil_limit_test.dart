import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/user_database.dart';

void main() {
  late UserDatabase db;
  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> add(String name) =>
      db.addBookmarkSet(name: name, color: 1, surah: 1, ayah: 1, page: 1);

  test('eight named fawasil, then the ninth is refused', () async {
    for (var i = 0; i < maxFawasil; i++) {
      await add('f$i');
    }
    expect(await db.canAddFasil(), isFalse);
    await expectLater(add('ninth'), throwsA(isA<FawasilLimitReached>()));
    expect(await db.fawasilCount(), maxFawasil);
  });

  test('the four fixed marks, once placed, count toward the eight', () async {
    for (final k in MarkKind.values) {
      await db.setMark(k, name: k.name, surah: 1, ayah: 1, page: 1);
    }
    for (var i = 0; i < maxFawasil - MarkKind.values.length; i++) {
      await add('f$i');
    }
    expect(await db.fawasilCount(), maxFawasil);
    expect(await db.canAddFasil(), isFalse);
    await expectLater(add('fifth'), throwsA(isA<FawasilLimitReached>()));
  });

  test('a fixed mark never placed takes no place', () async {
    await db.setMark(
      MarkKind.values.first,
      name: 'x',
      surah: 1,
      ayah: 1,
      page: 1,
    );
    for (var i = 0; i < maxFawasil - 1; i++) {
      await add('f$i');
    }
    expect(await db.canAddFasil(), isFalse);
    expect(await db.fawasilCount(), maxFawasil);
  });

  test('a reader over the limit keeps all; a fixed mark still moves', () async {
    for (var i = 0; i < maxFawasil; i++) {
      await add('f$i');
    }
    for (final k in MarkKind.values) {
      await db.setMark(k, name: k.name, surah: 1, ayah: 1, page: 1);
    }
    expect(await db.fawasilCount(), maxFawasil + MarkKind.values.length);
    await db.setMark(
      MarkKind.values.first,
      name: 'x',
      surah: 2,
      ayah: 1,
      page: 2,
    );
    expect(await db.canAddFasil(), isFalse);
  });

  test('a deleted fasil frees a place; undo puts it back whole', () async {
    final ids = [for (var i = 0; i < maxFawasil; i++) await add('f$i')];
    await db.setBookmarkSetStyle(ids[2], look: 'tab', material: 'linen');
    final row = (await db.watchBookmarkSets().first).firstWhere(
      (r) => r.id == ids[2],
    );
    await db.deleteBookmarkSet(ids[2]);
    expect(await db.canAddFasil(), isTrue);
    await db.restoreBookmarkSet(row);
    final back = (await db.watchBookmarkSets().first).firstWhere(
      (r) => r.id == ids[2],
    );
    expect(
      (back.uuid, back.look, back.material, back.sortOrder),
      (row.uuid, 'tab', 'linen', row.sortOrder),
    );
  });

  test('new fawasil go last; reorder sets the edge order', () async {
    final a = await add('a');
    final b = await add('b');
    final c = await add('c');
    var rows = await db.watchBookmarkSets().first;
    expect(rows.map((r) => r.id), [a, b, c]);
    await db.reorderBookmarkSets([c, a, b]);
    rows = await db.watchBookmarkSets().first;
    expect(rows.map((r) => r.id), [c, a, b]);
  });
}
