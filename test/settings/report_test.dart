import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/settings/report/problem_report.dart';
import 'package:tibyan/features/settings/report/report_screen.dart';
import 'package:tibyan/features/settings/settings_widgets.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// «الإبلاغ عن مشكلة»: validation, the device facts, sending, the offline
/// queue and the limit on the device.
void main() {
  const device = ReportDevice(
    appVersion: '1.2.3 (45)',
    platform: 'android',
    osVersion: '14',
  );
  ProblemReport report([String text = 'الصوت لا يعمل']) =>
      ProblemReport(type: ReportType.bug, description: text, device: device);

  group('ReportService', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('sends the report as JSON to the endpoint', () async {
      http.Request? got;
      final s = ReportService(
        prefs,
        client: MockClient((r) async {
          got = r;
          return http.Response('{"id":1}', 201);
        }),
      );
      expect(await s.submit(report()), ReportOutcome.sent);
      expect(got!.url, reportEndpoint);
      final body = jsonDecode(got!.body) as Map;
      expect(body['type'], 'bug');
      expect(body['app_version'], '1.2.3 (45)');
      expect(body.containsKey('email'), isFalse);
    });

    test('offline: queued, then sent by flush', () async {
      var online = false;
      var posts = 0;
      final s = ReportService(
        prefs,
        client: MockClient((r) async {
          if (!online) throw const SocketExceptionLike();
          posts++;
          return http.Response('{}', 201);
        }),
      );
      expect(await s.submit(report()), ReportOutcome.queued);
      expect(s.queue, hasLength(1));
      online = true;
      expect(await s.flush(), 1);
      expect(s.queue, isEmpty);
      expect(posts, 1);
    });

    test('a server error is retried later; a rejection is not', () async {
      var code = 503;
      final s = ReportService(
        prefs,
        minGap: Duration.zero,
        client: MockClient((r) async => http.Response('', code)),
      );
      expect(await s.submit(report()), ReportOutcome.queued);
      code = 422;
      expect(await s.submit(report()), ReportOutcome.failed);
      expect(await s.flush(), 0);
      expect(s.queue, isEmpty);
    });

    test(
      'the device limit: a gap between reports and a cap per hour',
      () async {
        var now = DateTime(2026, 1, 1, 10);
        final s = ReportService(
          prefs,
          now: () => now,
          maxPerHour: 2,
          client: MockClient((r) async => http.Response('{}', 201)),
        );
        expect(await s.submit(report()), ReportOutcome.sent);
        expect(await s.submit(report()), ReportOutcome.rateLimited);
        now = now.add(const Duration(minutes: 1));
        expect(await s.submit(report()), ReportOutcome.sent);
        now = now.add(const Duration(minutes: 1));
        expect(await s.submit(report()), ReportOutcome.rateLimited);
        now = now.add(const Duration(hours: 1));
        expect(await s.submit(report()), ReportOutcome.sent);
      },
    );

    test('the queue keeps the newest ten reports', () async {
      var now = DateTime(2026, 1, 1, 10);
      final s = ReportService(
        prefs,
        now: () => now,
        maxPerHour: 100,
        minGap: Duration.zero,
        client: MockClient((r) async => http.Response('', 503)),
      );
      for (var i = 0; i < 12; i++) {
        now = now.add(const Duration(minutes: 1));
        expect(await s.submit(report('بلاغ رقم $i')), ReportOutcome.queued);
      }
      expect(s.queue, hasLength(10));
      expect(jsonDecode(s.queue.first)['description'], 'بلاغ رقم 2');
      expect(jsonDecode(s.queue.last)['description'], 'بلاغ رقم 11');
    });

    test('a queued report is dropped after 14 days, contact and all', () async {
      var now = DateTime(2026, 1, 1, 10);
      final s = ReportService(
        prefs,
        now: () => now,
        client: MockClient((r) async => http.Response('', 503)),
      );
      final withContact = ProblemReport(
        type: ReportType.bug,
        description: 'الصوت لا يعمل',
        phone: '+20 100 123 4567',
        email: 'a@b.co',
        device: device,
      );
      expect(await s.submit(withContact), ReportOutcome.queued);
      now = now.add(const Duration(days: 13));
      expect(s.queue, hasLength(1));
      now = now.add(const Duration(days: 2));
      expect(s.queue, isEmpty);
      await s.flush();
      expect(prefs.getStringList(ReportService.queueKey), isNull);
    });

    test('a sent report leaves the device with its phone and email', () async {
      var online = false;
      final s = ReportService(
        prefs,
        client: MockClient((r) async {
          if (!online) return http.Response('', 503);
          return http.Response('{}', 201);
        }),
      );
      final withContact = ProblemReport(
        type: ReportType.bug,
        description: 'الصوت لا يعمل',
        phone: '+20 100 123 4567',
        email: 'a@b.co',
        device: device,
      );
      expect(await s.submit(withContact), ReportOutcome.queued);
      expect(
        prefs.getStringList(ReportService.queueKey).toString(),
        contains('a@b.co'),
      );
      online = true;
      expect(await s.flush(), 1);
      final left = prefs.getStringList(ReportService.queueKey);
      expect(left.toString(), isNot(contains('a@b.co')));
      expect(left.toString(), isNot(contains('4567')));
    });

    test('a queue from before the dates were kept still sends', () async {
      SharedPreferences.setMockInitialValues({
        ReportService.queueKey: [jsonEncode(report().toJson())],
      });
      final old = await SharedPreferences.getInstance();
      final s = ReportService(
        old,
        client: MockClient((r) async => http.Response('{}', 201)),
      );
      expect(s.queue, hasLength(1));
      expect(await s.flush(), 1);
      expect(s.queue, isEmpty);
    });

    test('email and phone are optional but checked', () {
      expect(isValidReportEmail(''), isTrue);
      expect(isValidReportEmail('a@b.co'), isTrue);
      expect(isValidReportEmail('a@b'), isFalse);
      expect(isValidReportPhone(''), isTrue);
      expect(isValidReportPhone('+20 100 123 4567'), isTrue);
      expect(isValidReportPhone('abc'), isFalse);
    });
  });

  group('the form', () {
    late ThemeRegistry registry;
    setUpAll(() async => registry = await ThemeRegistry.load(rootBundle));

    Future<List<http.Request>> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final sent = <http.Request>[];
      tester.view
        ..physicalSize = const Size(420, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sp),
            themeRegistryProvider.overrideWithValue(registry),
            appVersionProvider.overrideWith((ref) async => '1.2.3 (45)'),
            reportHttpClientProvider.overrideWithValue(
              MockClient((r) async {
                sent.add(r);
                return http.Response('{"id":1}', 201);
              }),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(
              style: registry.byId(registry.defaultStyleId),
              mode: ThemeModeId.light,
              uiFont: UiFont.changa,
              elderly: false,
              interfaceStyle: defaultInterfaceStyle,
            ),
            home: const ReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('shows the attached device facts and the crash switch', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('إصدار التطبيق: 1.2.3 (45)'), findsOneWidget);
      expect(find.text('إرسال تقارير الأعطال'), findsOneWidget);
      expect(find.text('عطل'), findsOneWidget);
    });

    testWidgets('validates, then sends', (tester) async {
      final sent = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();
      expect(find.text('اكتب خمسة أحرف على الأقل'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('report-description')),
        'التسميع لا يسمعني',
      );
      await tester.enterText(
        find.byKey(const ValueKey('report-email')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();
      expect(find.text('البريد الإلكتروني غير صحيح'), findsOneWidget);
      expect(sent, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('report-email')),
        'me@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(jsonDecode(sent.single.body)['email'], 'me@example.com');
      expect(find.text('وصل بلاغك، شكرا لك.'), findsOneWidget);
    });
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
