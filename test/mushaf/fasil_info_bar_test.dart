import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The tabs above the text (the open one too) hang from the page's top,
/// painted over its info bar (surah, juz, hizb), never under it: whole
/// where the text leaves room, else down to the text and never over it.
void main() {
  const marks = [
    FasilMark(id: 1, name: 'قراءة', color: Color(0xFF2F6FD0), page: 1),
    FasilMark(id: 2, name: 'الكهف', color: Color(0xFF2E9A53), page: 1),
  ];
  const barKey = Key('info-bar');

  Future<void> pump(
    WidgetTester tester, {
    required FasilLook look,
    required bool outerRight,
    required bool keepClear,
    double textTop = 10,
  }) async {
    const bar = SizedBox(key: barKey, height: 30, width: double.infinity);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 393,
            height: 700,
            child: FasilPageLayer(
              key: UniqueKey(),
              marks: marks,
              look: look,
              outerRight: outerRight,
              child: Column(
                children: [
                  keepClear ? const FasilKeepClear(child: bar) : bar,
                  Expanded(
                    child: FasilTextBlock(
                      rect: Rect.fromLTRB(14, textTop, 379, 630),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  const looks = {
    'tab': FasilLook(style: FasilStyle.tab, motion: false),
    'tab elderly': FasilLook(
      style: FasilStyle.tab,
      elderly: true,
      motion: false,
    ),
    // A ribbon with no margin on a phone falls back to a short tab.
    'ribbon': FasilLook(style: FasilStyle.ribbon, motion: false),
  };

  for (final MapEntry(key: name, value: look) in looks.entries) {
    for (final outerRight in [true, false]) {
      for (final textTop in [10.0, 80.0]) {
        testWidgets('$name, ${outerRight ? 'right' : 'left'}, text at '
            '$textTop: the tabs hang over the bar, off the text', (
          tester,
        ) async {
          await pump(
            tester,
            look: look,
            outerRight: outerRight,
            keepClear: true,
            textTop: textTop,
          );
          final bar = tester.getRect(find.byKey(barKey));
          final text = bar.bottom + textTop;
          for (final m in marks) {
            final entrance = find.byKey(ValueKey('fasil-entrance-${m.id}'));
            final r = tester.getRect(entrance);
            final whole = tester.getSize(
              find.descendant(of: entrance, matching: find.byType(FasilTab)),
            );
            expect(r.top, 0, reason: '${m.name} $r');
            expect(r.overlaps(bar), isTrue, reason: 'over the bar');
            expect(r.bottom, lessThanOrEqualTo(text));
            expect(
              r.height,
              moreOrLessEquals(math.min(whole.height, text - 2), epsilon: .5),
            );
          }
        });
      }
    }
  }

  testWidgets('without the info bar told, the tab hangs from the top', (
    tester,
  ) async {
    await pump(tester, look: looks['tab']!, outerRight: true, keepClear: false);
    final r = tester.getRect(find.byKey(const ValueKey('fasil-entrance-1')));
    expect(r.top, 0);
  });
}
