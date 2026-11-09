import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/privacy/store_privacy_prompt.dart';
import 'package:tibyan/core/settings/settings_controller.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// A first screen that offers the notice, as onboarding and home do.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    maybeShowStorePrivacy(context, ref);
    return const Scaffold(body: SizedBox.expand());
  }
}

void main() {
  late SharedPreferences prefs;

  Future<void> pump(
    WidgetTester tester, {
    required bool huawei,
    Map<String, Object> initial = const {},
    String locale = 'ar',
    bool elderly = false,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    final registry = (await tester.runAsync(
      () => ThemeRegistry.load(rootBundle),
    ))!;
    prefs = await SharedPreferences.getInstance();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storePrivacyPromptProvider.overrideWithValue(huawei),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            style: registry.byId('zakhrafa'),
            mode: ThemeModeId.light,
            uiFont: UiFont.plex,
            elderly: elderly,
            interfaceStyle: defaultInterfaceStyle,
          ),
          home: const _Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final dialog = find.byKey(const Key('storePrivacyDialog'));

  testWidgets('Huawei build: shows on first launch, not dismissible by a '
      'tap outside', (tester) async {
    await pump(tester, huawei: true);
    expect(dialog, findsOneWidget);
    expect(find.text('سياسة الخصوصية'), findsOneWidget);
    expect(find.text('اقرأ سياسة الخصوصية'), findsOneWidget);
    expect(find.text('موافق'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);

    await tester.tap(find.byKey(const Key('storePrivacyAccept')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(prefs.getBool(StorePrivacyPrompt.acceptedKey), isTrue);
  });

  testWidgets('Huawei build: not shown again after acceptance', (tester) async {
    await pump(
      tester,
      huawei: true,
      initial: {StorePrivacyPrompt.acceptedKey: true},
    );
    expect(dialog, findsNothing);
  });

  testWidgets('other builds: never shown', (tester) async {
    await pump(tester, huawei: false);
    expect(dialog, findsNothing);
    expect(prefs.getBool(StorePrivacyPrompt.acceptedKey), isNull);
  });

  test('the policy link follows the language', () {
    expect(
      privacyPolicyUrl(const Locale('ar')).toString(),
      'https://altibyan.app/privacy',
    );
    expect(
      privacyPolicyUrl(const Locale('en')).toString(),
      'https://altibyan.app/privacy/en',
    );
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('elderly mode ($locale): 56 dp targets, labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, huawei: true, locale: locale, elderly: true);
      for (final key in [
        'storePrivacyRead',
        'storePrivacyAccept',
        'storePrivacyExit',
      ]) {
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(elderlyTarget),
          reason: key,
        );
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(const Key('storePrivacyAccept')));
      await tester.pumpAndSettle();
      handle.dispose();
    });
  }
}
