import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// A page built again with the same list of fawasil (the reader keeps it
/// while they do not change) reuses its bookmarks: they are not built anew
/// on every page turn.
void main() {
  const hifz = FasilMark(
    id: 1,
    name: 'حفظ',
    color: Color(0xFFB23A3A),
    page: 50,
  );
  const ribbon = FasilLook(style: FasilStyle.ribbon, motion: false);

  Widget app(List<FasilMark> marks, FasilLook look, int n) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: SizedBox(
        width: 400,
        height: 700,
        child: FasilPageLayer(
          marks: marks,
          look: look,
          outerRight: true,
          // A new page widget each time, as each build gives.
          child: SizedBox.expand(key: ValueKey(n)),
        ),
      ),
    ),
  );

  Widget ribbonWidget(WidgetTester tester) =>
      tester.widget(find.byType(FasilRibbon));

  testWidgets('the same list reuses the bookmarks it built', (tester) async {
    final marks = [hifz];
    await tester.pumpWidget(app(marks, ribbon, 0));
    final first = ribbonWidget(tester);
    await tester.pumpWidget(app(marks, ribbon, 1));
    expect(ribbonWidget(tester), same(first));

    // A new list (the fawasil changed), or another look: built again.
    await tester.pumpWidget(app([hifz], ribbon, 2));
    final second = ribbonWidget(tester);
    expect(second, isNot(same(first)));
    final list = [hifz];
    await tester.pumpWidget(app(list, ribbon, 3));
    await tester.pumpWidget(
      app(list, const FasilLook(style: FasilStyle.ribbon), 4),
    );
    expect(ribbonWidget(tester), isNot(same(second)));
  });
}
