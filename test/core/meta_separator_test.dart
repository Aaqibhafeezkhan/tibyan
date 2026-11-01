import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/ui/meta_separator.dart';

Widget _host(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('MetaSeparator renders a small star hidden from semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const MetaSeparator(fontSize: 20)));
    final paint = find.descendant(
      of: find.byType(MetaSeparator),
      matching: find.byType(CustomPaint),
    );
    expect(paint, findsOneWidget);
    expect(tester.getSize(paint), const Size.square(11)); // 0.55em
    expect(
      find.descendant(
        of: find.byType(MetaSeparator),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('MetaText draws stars, not dots, and reads pauses', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const MetaText('الكهف | الآية ٨٤ · صفحة ٣٠٣')),
    );
    expect(find.byType(MetaSeparator), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
    expect(find.bySemanticsLabel('الكهف | الآية ٨٤، صفحة ٣٠٣'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('MetaText without a separator is a plain Text', (tester) async {
    await tester.pumpWidget(_host(const MetaText('صفحة ٣٠٣')));
    expect(find.byType(MetaSeparator), findsNothing);
    expect(find.text('صفحة ٣٠٣'), findsOneWidget);
  });

  test('plain and spoken forms carry no dot', () {
    expect(plainMeta('الجزء ٣ · الصفحة ٤٢'), 'الجزء ٣ – الصفحة ٤٢');
    expect(spokenMeta('Juz 3 · Page 42'), 'Juz 3, Page 42');
  });
}
