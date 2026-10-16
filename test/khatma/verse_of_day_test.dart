import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/services/verse_of_day.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Placeholder rows: the tests are about the choice and the keys, so no
/// verse text is used (only marker strings of a given length).
AyahRow _ayah(int id, {String text = 'x', int basmala = 0}) => AyahRow(
  id: id,
  surah: (id - 1) % 114 + 1,
  number: (id - 1) ~/ 114 + 1,
  verseText: text,
  displayText: text,
  basmalaPrefix: basmala,
  textSearch: text,
  searchBasmalaPrefix: basmala,
  juz: 1,
  hizbQuarter: 1,
  manzil: 1,
  page: 1,
  page1405: 1,
  textSourceId: 1,
  displaySourceId: 1,
  pageSourceId: 1,
  pageShamarly: 1,
  pageShamarlyEnd: 1,
);

final _surahs = [
  for (var i = 1; i <= 114; i++)
    SurahRow(
      id: i,
      nameAr: 'س$i',
      nameEn: 'S$i',
      meaningEn: '',
      revelation: 'meccan',
      revelationOrder: i,
      ayahCount: 60,
      startPage: 1,
      startPage1405: 1,
      sourceId: 1,
      startPageShamarly: 1,
    ),
];

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('the draw is a pure function of the date, within the mushaf', () {
    final day = Day(2026, 10, 16);
    expect(verseIdFor(day), verseIdFor(Day(2026, 10, 16)));
    expect(verseIdFor(day, 3), verseIdFor(day, 3));
    final ids = {for (var i = 0; i < 365; i++) verseIdFor(day.add(i))};
    expect(ids.every((id) => id >= 1 && id <= 6236), isTrue);
    // Spread over the mushaf, not stuck on a few verses.
    expect(ids.length, greaterThan(300));
    expect(verseIdFor(day), isNot(verseIdFor(day, 1)));
  });

  test('the basmala a first verse carries is left out', () {
    expect(verseOfDayText(_ayah(1, text: 'BBBBtext', basmala: 4)), 'text');
    expect(verseOfDayText(_ayah(1, text: 'text')), 'text');
  });

  test('entries: the same verses for the same days; too long is drawn '
      'again', () async {
    final from = Day(2026, 10, 16);
    final first = verseIdFor(from);
    final asked = <int>[];
    Future<AyahRow> ayahById(int id) async {
      asked.add(id);
      // The first draw of the first day is too long; its basmala does not
      // count toward the length.
      if (id == first && asked.length == 1) {
        return _ayah(id, text: 'y' * (verseOfDayMaxLength + 1));
      }
      return _ayah(id, text: '${'b' * 5}short', basmala: 5);
    }

    final a = await verseOfDayEntries(
      ayahById: ayahById,
      surahs: _surahs,
      l: l,
      from: from,
      days: 3,
    );
    expect(asked[1], verseIdFor(from, 1), reason: 'drawn again');
    expect(
      a['vod_days'],
      [for (var i = 0; i < 3; i++) from.add(i).key].join(','),
    );
    expect(a['vod_text_${from.key}'], 'short');
    final uri = Uri.parse(a['vod_uri_${from.key}']!);
    expect((uri.scheme, uri.host), ('tibyan', 'verse'));
    final again = await verseOfDayEntries(
      ayahById: (id) async => _ayah(id, text: 'short'),
      surahs: _surahs,
      l: l,
      from: from,
      days: 3,
    );
    for (var i = 1; i < 3; i++) {
      final k = from.add(i).key;
      expect(again['vod_uri_$k'], a['vod_uri_$k']);
    }
  });

  test('the month written is kept until it runs short or the language '
      'changes', () {
    final from = Day(2026, 10, 1);
    final stamp = verseOfDayStamp('ar', from);
    expect(verseOfDayStale(null, lang: 'ar', today: from), isTrue);
    expect(verseOfDayStale(stamp, lang: 'ar', today: from), isFalse);
    expect(verseOfDayStale(stamp, lang: 'ar', today: from.add(23)), isFalse);
    expect(verseOfDayStale(stamp, lang: 'ar', today: from.add(24)), isTrue);
    expect(verseOfDayStale(stamp, lang: 'en', today: from), isTrue);
    expect(verseOfDayStale(stamp, lang: 'ar', today: from.add(-1)), isTrue);
    expect(verseOfDayStale('garbage', lang: 'ar', today: from), isTrue);
  });
}
