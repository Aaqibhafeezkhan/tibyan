import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_sheet.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// The new-fasil name dialog owns its text controller: it answers the
/// trimmed name, and closing it (saved or cancelled) leaves nothing behind.
void main() {
  Future<Future<String?>> open(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final result = showDialog<String>(
      context: ctx,
      builder: (_) => const FasilNameDialog(),
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('saving answers the trimmed name', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), '  ورد الفجر  ');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(await result, 'ورد الفجر');
    expect(find.byType(FasilNameDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling answers nothing', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(tester.takeException(), isNull);
  });
}
