import '../../hifz/domain/recitation_record.dart';
import 'alignment_engine.dart';
import 'expected_words.dart';
import 'tasmee_report.dart';

/// The record a voice session leaves: each verse's counts and accuracy, and
/// the words read wrong or skipped by their place (never their text). A
/// word shown by the hint is neither.
RecitationRecord tasmeeRecord({
  required TasmeeReport report,
  required TasmeeEngine engine,
  required List<ExpectedWord> words,
  required Set<int> hinted,
  required DateTime startedAt,
  required DateTime endedAt,
  String? sensitivity,
}) => RecitationRecord(
  kind: RecitationKind.voice,
  startedAt: startedAt,
  endedAt: endedAt,
  sensitivity: sensitivity,
  verses: [
    for (final v in report.verses)
      VerseResultRecord(
        verse: v.verseId,
        accuracy: v.accuracy,
        words: v.words,
        wrong: v.wrong,
        skipped: v.skipped,
        corrected: v.corrected,
        doubtful: v.doubtful,
      ),
  ],
  slips: [
    for (final w in words)
      if (!hinted.contains(w.index))
        if (engine.statusOf(w.index)
            case WordStatus.wrong || WordStatus.skipped)
          (
            verse: w.verseId,
            word: w.word,
            skipped: engine.statusOf(w.index) == WordStatus.skipped,
          ),
  ],
);
