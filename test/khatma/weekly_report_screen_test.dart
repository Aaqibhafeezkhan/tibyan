import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/ui/look_kit.dart';
import 'package:tibyan/features/khatma/domain/day.dart';
import 'package:tibyan/features/khatma/domain/weekly_report.dart';
import 'package:tibyan/features/khatma/presentation/weekly_report_screen.dart';
import 'package:tibyan/features/khatma/weekly_report_providers.dart';

import '../tasmee/tasmee_test_env.dart';

void main() {
  late TasmeeTestData data;
  setUpAll(() => data = TasmeeTestData.open());
  tearDownAll(() => data.close());

  const last = Day(2026, 10, 26);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    WeeklyReport report,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => data.root.path,
    );
    tester.view
      ..physicalSize = const Size(430, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await tasmeeContainer(
      tester,
      data,
      overrides: [weeklyReportProvider.overrideWith((ref, _) => report)],
    );
    await tester.pumpWidget(
      tasmeeApp(
        container,
        const LookTheme(child: WeeklyReportScreen()),
        theme: tasmeeTheme(container),
      ),
    );
    await settle(tester);
    return container;
  }

  testWidgets('a quiet week: a fresh start, no numbers, reminder off', (
    tester,
  ) async {
    await pump(tester, buildWeeklyReport(last: last));
    expect(find.textContaining('بداية جديدة'), findsOneWidget);
    expect(find.textContaining('ولا بأس'), findsOneWidget);
    expect(find.text('الصفحات'), findsNothing);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
  });

  testWidgets('a week with reading, a recitation and a khatma', (tester) async {
    final t = last.start.add(const Duration(hours: 9));
    await pump(
      tester,
      buildWeeklyReport(
        last: last,
        reading: [(t, t.add(const Duration(minutes: 12)), 4)],
        recitations: [t],
        recitedVerses: [(t, 1), (t, 2)],
        khatmas: [
          (
            title: 'ختمة رمضان',
            progress: 0.25,
            coveredWeight: 25,
            weightOn: (d) => d == last ? 5 : 0,
          ),
        ],
      ),
    );
    expect(find.text('الصفحات'), findsOneWidget);
    expect(find.text('٤'), findsWidgets);
    expect(find.text('جلسات التسميع'), findsOneWidget);
    expect(find.text('ختمة رمضان'), findsOneWidget);
    expect(find.text('٢٥٪ من الختمة'), findsOneWidget);
    expect(find.text('قرأت ٥٪ منها هذا الأسبوع'), findsOneWidget);
    // The day's bar is read out with its minutes.
    expect(find.bySemanticsLabel(RegExp('١٢ دقيقة')), findsOneWidget);
  });

  testWidgets('turning the reminder on keeps it and shows its time', (
    tester,
  ) async {
    final container = await pump(tester, buildWeeklyReport(last: last));
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(container.read(settingsProvider).weeklyReminder, isTrue);
    expect(find.text('يوم التذكير ووقته'), findsOneWidget);
  });
}
