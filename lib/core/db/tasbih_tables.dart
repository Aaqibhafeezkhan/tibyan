import 'package:drift/drift.dart';

import 'habit_tables.dart' show SyncColumns;

/// «المسبحة»: a dhikr the reader added («من إضافتك»). The app's own adhkar
/// come from `assets/tasbih/adhkar.json` and are not stored here.
@DataClassName('TasbihDhikrRow')
class TasbihDhikrs extends Table with SyncColumns {
  @override
  String get tableName => 'tasbih_dhikr';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text()();

  /// The reader's own note of where it is from; optional.
  TextColumn get reference => text().nullable()();

  /// The count to a round; null for none.
  IntColumn get target => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// The calm daily log: how many times a dhikr was counted on a local day
/// (`yyyy-MM-dd`) and how many rounds closed. One row a dhikr a day a
/// device; only the last 30 days are kept.
@DataClassName('TasbihDayRow')
class TasbihDays extends Table {
  @override
  String get tableName => 'tasbih_day';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text()();

  /// `app:<id>` for the app's adhkar, `user:<uuid>` for the reader's.
  TextColumn get dhikr => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();
  IntColumn get rounds => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  /// The device that counted: empty for this device, another device's
  /// sync id for counts that came through «المزامنة». A day's total is the
  /// sum over devices.
  TextColumn get device => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {day, dhikr, device},
  ];
}
