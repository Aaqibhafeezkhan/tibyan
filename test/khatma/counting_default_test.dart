import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/khatma/data/khatmah_store.dart';
import 'package:tibyan/features/khatma/domain/khatmah.dart';

/// The counting default: khatmas saved before «تأكيد إتمام الورد» existed
/// (build 32 and earlier) keep counting automatically; new khatmas start
/// with the confirmation.
void main() {
  test('a build-32 khatma keeps auto counting; unknown modes too', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final t = DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
    // As build 32 wrote it: no counting mode given (the column's default),
    // and a value from a newer or older build this one does not know.
    await db.customStatement(
      'INSERT INTO khatma (uuid, updated_at, title, edition, start_date, '
      'target_date, is_primary, created_at) '
      "VALUES ('old', $t, 'ختمة', 'madina1441', '2026-10-01', "
      "'2026-10-30', 1, $t)",
    );
    await db.customStatement(
      'INSERT INTO khatma (uuid, updated_at, title, edition, start_date, '
      'target_date, counting_mode, created_at) '
      "VALUES ('odd', $t, 'ختمة', 'madina1441', '2026-10-01', "
      "'2026-10-30', 'legacy', $t)",
    );
    final store = KhatmahStore(db);
    expect((await store.byUuid('old'))!.counting, CountingMode.auto);
    expect((await store.byUuid('odd'))!.counting, CountingMode.auto);
  });

  test('a new khatma starts with the wird confirmation', () {
    expect(
      const AppSettings(styleId: 'x').khatmaCountingMode,
      CountingMode.wirdConfirm,
    );
  });
}
