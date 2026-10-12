import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/l10n/app_localizations.dart';

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('Arabic verse counts agree with the number', () {
    const expected = {
      1: 'آية واحدة',
      2: 'آيتان',
      3: '3 آيات',
      7: '7 آيات',
      10: '10 آيات',
      11: '11 آية',
      99: '99 آية',
      100: '100 آية',
      286: '286 آية',
    };
    expected.forEach((n, text) => expect(ar.ayahCount(n, '$n'), text));
  });

  test('Arabic pages, days, words and times agree with the number', () {
    expect(ar.khatmaProgress('1', 7, '7'), '1 من 7 صفحات');
    expect(ar.khatmaProgress('5', 11, '11'), '5 من 11 صفحة');
    // The rule reads the last two digits: 604 ends in 04.
    expect(ar.khatmaProgress('5', 604, '604'), '5 من 604 صفحات');
    expect(ar.goalDays(30, '30'), 'المدة: 30 يومًا');
    expect(ar.goalDays(2, '2'), 'المدة: يومان');
    expect(ar.goalDays(10, '10'), 'المدة: 10 أيام');
    expect(ar.goalDays(100, '100'), 'المدة: 100 يوم');
    expect(ar.hardWordsCount(1, '1', 'x'), 'مرة واحدة · آخرها x');
    expect(ar.hardWordsCount(3, '3', 'x'), '3 مرات · آخرها x');
    expect(ar.searchCount(286, '286', 2, '2'), '286 موضعًا في آيتين');
  });

  test('English counts are one or other', () {
    for (final n in [1, 2, 3, 7, 10, 11, 99, 100, 286]) {
      expect(en.ayahCount(n, '$n'), n == 1 ? '1 verse' : '$n verses');
    }
    expect(en.goalDays(1, '1'), 'Length: 1 day');
    expect(en.khatmaProgress('3', 20, '20'), '3 of 20 pages');
  });
}
