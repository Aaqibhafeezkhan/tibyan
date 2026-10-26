import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/assistant/assistant_screen.dart';
import 'package:tibyan/features/assistant/tajweed_marks_screen.dart';
import 'package:tibyan/features/hifz/presentation/hifz_screen.dart';
import 'package:tibyan/features/khatma/presentation/journal_screen.dart';
import 'package:tibyan/features/khatma/presentation/khatma_screen.dart';
import 'package:tibyan/features/khatma/presentation/new_khatma_screen.dart';
import 'package:tibyan/features/khatma/presentation/reports_screen.dart';
import 'package:tibyan/features/khatma/presentation/weekly_report_screen.dart';
import 'package:tibyan/features/mushaf/presentation/downloads_center_screen.dart';
import 'package:tibyan/features/settings/storage_screen.dart';
import 'package:tibyan/features/tasmee/presentation/tasmee_settings_screen.dart';
import 'package:tibyan/features/tasmee/presentation/tasmee_setup_screen.dart';

import '../tasmee/tasmee_test_env.dart';

/// Under the Arabic interface, numbers are written in Arabic digits: no
/// Latin digit shows in the key screens' texts and fields (words in Latin
/// letters, such as a source's name or a version, are left out).
void main() {
  late TasmeeTestData data;
  setUpAll(() => data = TasmeeTestData.open());
  tearDownAll(() => data.close());

  final latinDigit = RegExp('[0-9]');
  final latinLetter = RegExp('[A-Za-z]');

  testWidgets('tasmee setup steppers: Arabic digits, typed in either', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await tasmeeContainer(tester, data);
    int? started;
    await tester.pumpWidget(
      tasmeeApp(
        container,
        LookTheme(
          child: Scaffold(
            body: SingleChildScrollView(
              child: TasmeeSetupSheet(
                onStart: (_) => started = 1,
                onClose: () {},
              ),
            ),
          ),
        ),
        theme: tasmeeTheme(container),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('ربع حزب'));
    await settle(tester);
    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields, isNotEmpty);
    for (final f in fields) {
      expect(f.controller.text, isNot(matches(latinDigit)));
    }
    // A number typed in Latin digits is still taken.
    await tester.enterText(find.byType(EditableText).first, '12');
    await settle(tester);
    expect(find.textContaining('١٢'), findsWidgets);
    expect(started, isNull);
  });

  final screens = <String, Widget>{
    'tasmee setup': Scaffold(
      body: SingleChildScrollView(
        child: TasmeeSetupSheet(onStart: (_) {}, onClose: () {}),
      ),
    ),
    'tasmee settings': const TasmeeSettingsScreen(),
    'khatma': const KhatmaScreen(),
    'khatma wizard': const NewKhatmaScreen(),
    'reports': const ReportsScreen(),
    'weekly report': const WeeklyReportScreen(),
    'journal': const JournalScreen(),
    'assistant': const AssistantScreen(),
    'tajweed marks': const TajweedMarksScreen(),
    'hifz': const HifzScreen(),
    'downloads': const DownloadsCenterScreen(),
    'storage': const StorageScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name: Arabic digits only', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => data.root.path,
      );
      tester.view
        ..physicalSize = const Size(430, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = await tasmeeContainer(tester, data);
      await tester.pumpWidget(
        tasmeeApp(
          container,
          LookTheme(child: screen),
          theme: tasmeeTheme(container),
        ),
      );
      await settle(tester);
      final found = <String>[];
      void check(String text) {
        if (latinDigit.hasMatch(text) && !latinLetter.hasMatch(text)) {
          found.add(text);
        }
      }

      for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
        check(t.text.toPlainText());
      }
      for (final f in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        check(f.controller.text);
      }
      expect(found, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
