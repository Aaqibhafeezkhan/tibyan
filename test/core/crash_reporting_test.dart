import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/crash/crash_consent.dart';
import 'package:tibyan/core/crash/crash_reporting.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('scrub', () {
    test('removes user, request, server and device names', () {
      final event = SentryEvent(
        user: SentryUser(id: 'u1', email: 'a@b.c', ipAddress: '1.2.3.4'),
        serverName: 'Ahmeds-iPhone',
        request: SentryRequest(url: 'https://x.test/?q=1'),
        contexts: Contexts(
          device: SentryDevice(name: "Ahmed's iPhone", model: 'iPhone17,1'),
        ),
      );
      final out = CrashReporting.scrub(event);
      expect(out.user, isNull);
      expect(out.request, isNull);
      expect(out.serverName, isNull);
      expect(out.contexts.device?.name, isNull);
      expect(out.contexts.device?.model, 'iPhone17,1');
    });

    test('keeps the kind of step, drops URLs and typed text', () {
      final event = SentryEvent(
        breadcrumbs: [
          Breadcrumb.http(
            url: Uri.parse('https://x.test/a?t=1'),
            method: 'GET',
          ),
          Breadcrumb(type: 'user', category: 'ui.click', message: 'search: x'),
          Breadcrumb(category: 'navigation', data: {'to': '/mushaf'}),
        ],
      );
      final crumbs = CrashReporting.scrub(event).breadcrumbs!;
      expect(crumbs, hasLength(3));
      expect(crumbs[0].data, isNull);
      expect(crumbs[1].message, isNull);
      expect(crumbs[2].data, {'to': '/mushaf'});
    });
  });

  test('configure turns PII off and native crash tracking on', () {
    final o = SentryFlutterOptions();
    CrashReporting.configure(o);
    expect(o.sendDefaultPii, isFalse);
    expect(o.attachScreenshot, isFalse);
    expect(o.attachStacktrace, isTrue);
    expect(o.enableWatchdogTerminationTracking, isTrue);
    expect(o.enableAppHangTracking, isTrue);
    expect(o.anrEnabled, isTrue);
    expect(o.enableNativeCrashHandling, isTrue);
    expect(o.tracesSampleRate, 0);
    expect(o.beforeSend, isNotNull);
  });

  group('consent', () {
    test('asks once, only when the build can send', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(CrashConsent.shouldAsk(prefs, available: false), isFalse);
      expect(CrashConsent.shouldAsk(prefs, available: true), isTrue);
      await prefs.setBool(CrashConsent.askedKey, true);
      expect(CrashConsent.shouldAsk(prefs, available: true), isFalse);
    });

    test('readers who already turned it on are not asked', () async {
      SharedPreferences.setMockInitialValues({
        'settings.crashReportsOptIn': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(CrashConsent.shouldAsk(prefs, available: true), isFalse);
    });

    test('the answer sets the setting and is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          themeRegistryProvider.overrideWithValue(
            await ThemeRegistry.load(rootBundle),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(c.dispose);
      await CrashConsent.answer(
        prefs,
        c.read(settingsProvider.notifier),
        agree: true,
      );
      expect(c.read(settingsProvider).crashReportsOptIn, isTrue);
      expect(prefs.getBool(CrashConsent.askedKey), isTrue);
      expect(CrashConsent.shouldAsk(prefs, available: true), isFalse);
    });

    for (final suggest in [true, false]) {
      testWidgets('sheet returns the choice (suggestAgree: $suggest)', (
        tester,
      ) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showCrashConsent(
                  context,
                  suggestAgree: suggest,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('ساعدنا نحسّن تبيان'), findsOneWidget);
        expect(
          find.byType(FilledButton),
          suggest ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byKey(const Key('crashConsentAgree')));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      });
    }
  });
}
