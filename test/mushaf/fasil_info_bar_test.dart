import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The tabs above the text (the open one too) hang from under the page's
/// info bar (surah, juz, hizb), never over it, on either side.
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
                  const Expanded(
                    child: FasilTextBlock(
                      rect: Rect.fromLTRB(14, 10, 379, 630),
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
      testWidgets('$name, ${outerRight ? 'right' : 'left'}: '
          'the tabs keep off the info bar and the text', (tester) async {
        await pump(tester, look: look, outerRight: outerRight, keepClear: true);
        final bar = tester.getRect(find.byKey(barKey));
        for (final m in marks) {
          final r = tester
              .getRect(find.byKey(ValueKey('fasil-entrance-${m.id}')))
              .deflate(.5);
          expect(r.overlaps(bar), isFalse, reason: '${m.name} $r over $bar');
          expect(r.top, greaterThanOrEqualTo(bar.bottom));
          expect(r.bottom, lessThanOrEqualTo(40));
          expect(r.height, greaterThan(4));
        }
      });
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
