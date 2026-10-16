// «آية اليوم»: one verse a day for the home screen widgets.
//
// The verse is drawn at random from the whole mushaf (docs/BACKLOG.md: no
// hand-picked list), but the draw is a pure function of the date, so every
// device shows the same verse on the same day. The widgets have no Quran
// text of their own: the app writes the coming days ahead, as it does for
// the khatma widget, and each widget reads the entry of the current day.
import 'dart:ui' show Locale;

import '../../../core/db/content_database.dart' show AyahRow, SurahRow;
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../domain/day.dart';

const _verses = 6236;

/// The longest verse a widget shows. A widget cannot scroll and a verse
/// must never be cut off with «…»: a longer draw is drawn again (by
/// length only; what the verse says plays no part).
const verseOfDayMaxLength = 260;

/// splitmix64: a well-mixed 64-bit hash, the same on every platform.
/// Dart's ints wrap at 64 bits, as the algorithm wants; its constants
/// (0x9E3779B97F4A7C15, 0xBF58476D1CE4E5B9, 0x94D049BB133111EB) are
/// written as the signed values of the same bits.
int _mix(int x) {
  var z = x + -7046029254386353131;
  z = (z ^ (z >>> 30)) * -4658895280553007687;
  z = (z ^ (z >>> 27)) * -7723592293110705685;
  return z ^ (z >>> 31);
}

/// The [attempt]th draw for [day]: a verse id, 1 … 6236 in mushaf order.
int verseIdFor(Day day, [int attempt = 0]) {
  final n = day.difference(const Day(1970, 1, 1));
  return (_mix(n * 31 + attempt) >>> 1) % _verses + 1;
}

/// The verse's text as the mushaf has it, without the basmala some
/// surahs' first verse carries in the source text.
String verseOfDayText(AyahRow a) =>
    a.basmalaPrefix > 0 ? a.verseText.substring(a.basmalaPrefix) : a.verseText;

/// The widget keys for [days] days from [from]: `vod_title`, `vod_days`,
/// and per day `vod_text_`, `vod_ref_` and `vod_uri_`; and `lang`, the
/// app's language, which sets every widget's direction.
Future<Map<String, String>> verseOfDayEntries({
  required Future<AyahRow> Function(int id) ayahById,
  required List<SurahRow> surahs,
  required AppLocalizations l,
  required Day from,
  int days = 30,
}) async {
  final ar = l.localeName == 'ar';
  final digits = NumberFormatter(Locale(l.localeName));
  final out = <String, String>{
    'lang': l.localeName,
    'vod_title': l.verseOfDayTitle,
  };
  final keys = <String>[];
  for (var i = 0; i < days; i++) {
    final day = from.add(i);
    var attempt = 0;
    var a = await ayahById(verseIdFor(day));
    while (verseOfDayText(a).length > verseOfDayMaxLength && attempt < 50) {
      a = await ayahById(verseIdFor(day, ++attempt));
    }
    final surah = surahs[a.surah - 1];
    keys.add(day.key);
    out['vod_text_${day.key}'] = verseOfDayText(a);
    out['vod_ref_${day.key}'] = l.journalVerseRef(
      ar ? surah.nameAr : surah.nameEn,
      digits(a.number),
    );
    out['vod_uri_${day.key}'] = Uri(
      scheme: 'tibyan',
      host: 'verse',
      queryParameters: {
        's': '${a.surah}',
        'a': '${a.number}',
        'homeWidget': '',
      },
    ).toString();
  }
  out['vod_days'] = keys.join(',');
  return out;
}

/// The preference that says which month of verses the widgets were last
/// given: `<language>|<first day>`.
const verseOfDayStampKey = 'widget.verseOfDay.written';

/// The stamp for entries written in [lang] from [from].
String verseOfDayStamp(String lang, Day from) => '$lang|${from.key}';

/// Whether the widgets need the verses written again: never written, in
/// another language, or fewer than [margin] days left ahead of [today]
/// of the [days] written. Otherwise the ~30 lookups are skipped.
bool verseOfDayStale(
  String? stamp, {
  required String lang,
  required Day today,
  int days = 30,
  int margin = 7,
}) {
  final parts = stamp?.split('|');
  if (parts == null || parts.length != 2 || parts[0] != lang) return true;
  final Day from;
  try {
    from = Day.parse(parts[1]);
  } catch (_) {
    return true;
  }
  final into = today.difference(from);
  return into < 0 || into > days - margin;
}
