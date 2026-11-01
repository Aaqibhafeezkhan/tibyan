import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/user_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_sheet.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// Each fasil may keep its own look and cloth; the rest follow the
/// reader's default, and mixed looks share one page edge.
void main() {
  Widget app(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(child: SizedBox(width: 400, height: 700, child: child)),
  );

  BookmarkSetRow row(int id, {String? look, String? material}) =>
      BookmarkSetRow(
        id: id,
        name: 'f$id',
        color: 0xFFB23A3A,
        surah: 2,
        ayah: id,
        page: 2,
        sortOrder: id,
        updatedAt: DateTime(2026),
        look: look,
        material: material,
      );

  test('null follows the default; an own look overrides it', () {
    const ribbon = FasilLook(style: FasilStyle.ribbon);
    final rows = [row(1), row(2, look: 'tab'), row(3, look: 'tint')];
    final marks = fasilMarksOf(rows, ribbon, (_) => 2);
    expect(marks.map((m) => m.id), [1, 2]);
    expect(ribbon.forMark(marks[0]).style, FasilStyle.ribbon);
    expect(ribbon.forMark(marks[1]).style, FasilStyle.tab);
    expect(fasilTints(rows, ribbon, (r) => r.id).keys, [3]);
    // A tinted default still draws the ones that chose a drawn look.
    const tint = FasilLook(style: FasilStyle.tint);
    expect(fasilMarksOf(rows, tint, (_) => 2).map((m) => m.id), [2]);
    expect(fasilTints(rows, tint, (r) => r.id).keys, [1, 3]);
  });

  test('an own cloth changes only that fasil', () {
    const silk = FasilLook(style: FasilStyle.ribbon);
    final marks = fasilMarksOf(
      [row(1), row(2, material: 'velvet')],
      silk,
      (_) => 2,
    );
    expect(silk.forMark(marks[0]), same(silk));
    expect(silk.forMark(marks[1]).material, FasilMaterial.velvet);
  });

  testWidgets('a ribbon and a tab on one edge, in order, not overlapping', (
    tester,
  ) async {
    const look = FasilLook(style: FasilStyle.ribbon, motion: false);
    final marks = fasilMarksOf(
      [row(1), row(2, look: 'tab'), row(3)],
      look,
      (_) => 2,
    );
    await tester.pumpWidget(
      app(
        FasilPageLayer(
          marks: marks,
          look: look,
          outerRight: true,
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byType(FasilRibbon), findsNWidgets(2));
    expect(find.byType(FasilTab), findsOneWidget);
    final rects = [
      for (final id in [1, 2, 3])
        tester.getRect(find.byKey(ValueKey('fasil-$id'))),
    ];
    // Right to left from the outer edge, each clear of the one before.
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].right, lessThanOrEqualTo(rects[i - 1].left + 1));
    }
  });
}
