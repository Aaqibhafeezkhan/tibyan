import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every string is in both languages: the same keys, the same placeholders,
/// nothing empty, and the Arabic side written in Arabic.
void main() {
  Map<String, dynamic> load(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;
  final ar = load('ar');
  final en = load('en');
  Set<String> keys(Map<String, dynamic> m) => {
    for (final k in m.keys)
      if (!k.startsWith('@')) k,
  };
  final holder = RegExp(r'\{(\w+)[,}]');
  // A plural branch's plain words («=1{day}») are not placeholders.
  final branch = RegExp(r'(=\d+|zero|one|two|few|many|other)\{[^{}]*\}');
  Set<String> holders(String s) => {
    for (final m in holder.allMatches(s.replaceAll(branch, ''))) m[1]!,
  };

  test('the same keys in Arabic and English', () {
    expect(keys(ar).difference(keys(en)), isEmpty, reason: 'missing in en');
    expect(keys(en).difference(keys(ar)), isEmpty, reason: 'missing in ar');
  });

  test('no empty strings, English placeholders all in Arabic', () {
    final bad = <String>[];
    for (final k in keys(ar)) {
      final a = ar[k] as String, e = en[k] as String;
      if (a.trim().isEmpty || e.trim().isEmpty) bad.add('$k empty');
      // Arabic plurals may count with an extra placeholder of their own.
      if (!holders(a).containsAll(holders(e))) {
        bad.add('$k placeholders');
      }
    }
    expect(bad, isEmpty);
  });

  test('the Arabic strings are in Arabic', () {
    final arabic = RegExp('[؀-ۿ]');
    final latin = RegExp('[A-Za-z]{3}');
    final bad = [
      for (final k in keys(ar))
        if (latin.hasMatch((ar[k] as String).replaceAll(holder, '')) &&
            !arabic.hasMatch(ar[k] as String) &&
            // Names that stay as they are: the language, a font.
            !const {'languageEnglish', 'uiFontChanga'}.contains(k))
          k,
    ];
    expect(bad, isEmpty);
  });
}
