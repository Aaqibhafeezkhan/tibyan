import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/tasmee/domain/arabic_normalizer.dart';
import 'package:tibyan/features/tasmee/domain/word_match.dart';

bool _differs(String a, String b) =>
    differsByLeadingPrefix(normalizeArabicWord(a), normalizeArabicWord(b));

void main() {
  test('a leading waw, fa, ba or al dropped or added', () {
    expect(_differs('إنهم', 'وَإِنَّهُمۡ'), isTrue);
    expect(_differs('ذوقوا', 'فَذُوقُواْ'), isTrue);
    expect(_differs('بالعذاب', 'ٱلۡعَذَابَ'), isTrue);
    expect(_differs('عذاب', 'ٱلۡعَذَابَ'), isTrue);
  });

  test('other differences are not prefix slips', () {
    expect(_differs('وإنهم', 'وَإِنَّهُمۡ'), isFalse); // the same word
    expect(_differs('يعلمون', 'تعلمون'), isFalse); // another first letter
    expect(_differs('إنهم', 'لَهُم'), isFalse);
    expect(_differs('و', 'وَ'), isFalse);
    expect(_differs('ب', 'بل'), isFalse); // too short to be a prefix slip
  });
}
