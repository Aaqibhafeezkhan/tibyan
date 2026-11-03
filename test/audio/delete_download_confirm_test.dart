import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/audio/audio_downloads_screen.dart';
import 'package:tibyan/l10n/app_localizations.dart';

Future<bool?> _ask(WidgetTester tester, Locale locale, String tap) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await confirmDeleteSurahDownload(context, 'X'),
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.tap(find.text(tap));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('cancel keeps the download', (tester) async {
    expect(await _ask(tester, const Locale('en'), 'Cancel'), isFalse);
  });

  testWidgets('delete confirms', (tester) async {
    expect(await _ask(tester, const Locale('en'), 'Delete'), isTrue);
  });

  testWidgets('Arabic dialog', (tester) async {
    expect(await _ask(tester, const Locale('ar'), 'إلغاء'), isFalse);
  });
}
